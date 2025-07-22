defmodule CommandService.Infrastructure.CommandBus do
  @moduledoc """
  コマンドバスの実装

  コマンドを適切なハンドラーにルーティングして実行します
  """

  use GenServer

  alias CommandService.Application.Handlers.{
    CategoryCommandHandler,
    OrderCommandHandler,
    ProductCommandHandler,
    SagaCommandHandler
  }

  alias Shared.Infrastructure.Retry.{RetryStrategy, RetryPolicy}
  alias Shared.Telemetry.Tracing.MessagePropagator

  require Logger

  @type command :: struct()
  @type result :: {:ok, any()} | {:error, String.t()}

  # Client API

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  コマンドを実行する
  """
  @spec dispatch(command()) :: result()
  def dispatch(command) do
    GenServer.call(__MODULE__, {:dispatch, command})
  end

  @doc """
  コマンドを非同期で実行する（サガ用）
  """
  @spec dispatch_async(command()) :: :ok
  def dispatch_async(command) do
    GenServer.cast(__MODULE__, {:dispatch_async, command})
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:dispatch, command}, _from, state) do
    result =
      MessagePropagator.wrap_command_dispatch(command, fn cmd ->
        execute_command_with_retry(cmd)
      end)

    {:reply, result, state}
  end

  @impl true
  def handle_cast({:dispatch_async, command}, state) do
    Task.start(fn ->
      MessagePropagator.wrap_command_dispatch(command, fn cmd ->
        case execute_command_with_retry(cmd) do
          {:ok, _} = result ->
            Logger.info("Command executed successfully: #{inspect(command.__struct__)}")
            result

          {:error, reason} = error ->
            Logger.error("Command failed: #{inspect(command.__struct__)}, reason: #{reason}")
            error
        end
      end)
    end)

    {:noreply, state}
  end

  # Private functions

  @spec route_command(command()) :: result()
  defp route_command(%CommandService.Application.Commands.CategoryCommands.CreateCategory{} = cmd) do
    CategoryCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.CategoryCommands.UpdateCategory{} = cmd) do
    CategoryCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.CategoryCommands.DeleteCategory{} = cmd) do
    CategoryCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.ProductCommands.CreateProduct{} = cmd) do
    ProductCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.ProductCommands.UpdateProduct{} = cmd) do
    ProductCommandHandler.handle(cmd)
  end

  defp route_command(
         %CommandService.Application.Commands.ProductCommands.ChangeProductPrice{} = cmd
       ) do
    ProductCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.ProductCommands.DeleteProduct{} = cmd) do
    ProductCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.ProductCommands.UpdateStock{} = cmd) do
    ProductCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.ProductCommands.ReserveStock{} = cmd) do
    ProductCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.ProductCommands.ReleaseStock{} = cmd) do
    ProductCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.OrderCommands.CreateOrder{} = cmd) do
    OrderCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.OrderCommands.ConfirmOrder{} = cmd) do
    OrderCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.OrderCommands.CancelOrder{} = cmd) do
    OrderCommandHandler.handle(cmd)
  end

  # サガコマンドのルーティング
  defp route_command(%CommandService.Application.Commands.SagaCommands.ReserveInventory{} = cmd) do
    SagaCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.SagaCommands.ProcessPayment{} = cmd) do
    SagaCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.SagaCommands.ArrangeShipping{} = cmd) do
    SagaCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.SagaCommands.ConfirmOrder{} = cmd) do
    SagaCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.SagaCommands.ReleaseInventory{} = cmd) do
    SagaCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.SagaCommands.RefundPayment{} = cmd) do
    SagaCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.SagaCommands.CancelShipping{} = cmd) do
    SagaCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.SagaCommands.CancelOrder{} = cmd) do
    SagaCommandHandler.handle(cmd)
  end

  defp route_command(command) do
    {:error, "Unknown command: #{inspect(command)}"}
  end

  # リトライ機能を持つコマンド実行
  @spec execute_command_with_retry(command()) :: result()
  defp execute_command_with_retry(command) do
    RetryStrategy.execute_with_condition(
      fn ->
        try do
          route_command(command)
        rescue
          # データベース関連のエラー
          _e in [DBConnection.ConnectionError, Postgrex.Error] ->
            {:error, :database_timeout}

          # Firestore では StaleEntryError は発生しないため、この処理は削除
          # 将来的に同時実行制御が必要な場合は、Firestore のトランザクションを使用

          # イベントストアのバージョン競合
          _e in Shared.Infrastructure.EventStore.VersionConflictError ->
            {:error, :concurrent_modification}

          e ->
            # その他のエラーはリトライ不可能として扱う
            {:error, Exception.message(e)}
        end
      end,
      fn error ->
        RetryPolicy.retryable?(error)
      end,
      %{
        max_attempts: 3,
        base_delay: 50,
        max_delay: 1_000,
        backoff_type: :exponential,
        jitter: true
      }
    )
    |> case do
      {:ok, result} ->
        result

      {:error, :max_attempts_exceeded, errors} ->
        last_error = errors |> List.last() |> elem(1)
        {:error, last_error}

      {:error, error} ->
        {:error, error}
    end
  end
end
