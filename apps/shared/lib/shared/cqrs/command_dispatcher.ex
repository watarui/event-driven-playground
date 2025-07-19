defmodule Shared.CQRS.CommandDispatcher do
  @moduledoc """
  コマンドの動的ディスパッチャー

  プロトコルベースでコマンドを適切なハンドラーにルーティングし、
  べき等性、バリデーション、エラーハンドリングを提供する。
  """

  alias Shared.CQRS.Command
  alias Shared.Infrastructure.Idempotency.{IdempotencyKey, IdempotencyStore}

  require Logger

  @type dispatch_result :: {:ok, any()} | {:error, any()}
  @type dispatch_opts :: [
          idempotent: boolean(),
          timeout: non_neg_integer(),
          metadata: map()
        ]

  @doc """
  コマンドをディスパッチする

  ## Options
  - `:idempotent` - べき等実行を有効にする（デフォルト: true）
  - `:timeout` - タイムアウト（ミリ秒）
  - `:metadata` - 追加のメタデータ

  ## Examples
      dispatch(%CreateOrderCommand{...})
      dispatch(%UpdateProductCommand{...}, idempotent: false)
  """
  @spec dispatch(struct(), dispatch_opts()) :: dispatch_result()
  def dispatch(command, opts \\ []) do
    with :ok <- validate_command(command),
         {:ok, handler} <- get_handler(command) do
      if Keyword.get(opts, :idempotent, true) do
        dispatch_idempotent(command, handler, opts)
      else
        dispatch_direct(command, handler, opts)
      end
    end
  end

  @doc """
  コマンドを非同期でディスパッチする

  結果を待たずに即座に返る。
  """
  @spec dispatch_async(struct(), dispatch_opts()) :: {:ok, Task.t()} | {:error, any()}
  def dispatch_async(command, opts \\ []) do
    with :ok <- validate_command(command),
         {:ok, _handler} <- get_handler(command) do
      task =
        Task.async(fn ->
          dispatch(command, opts)
        end)

      {:ok, task}
    end
  end

  @doc """
  複数のコマンドをバッチでディスパッチする

  すべて成功するか、すべて失敗する（トランザクション的）。
  """
  @spec dispatch_batch([struct()], dispatch_opts()) :: {:ok, [any()]} | {:error, any()}
  def dispatch_batch(commands, opts \\ []) do
    # すべてのコマンドをバリデート
    with :ok <- validate_all_commands(commands) do
      # トランザクション内で実行
      results =
        Enum.map(commands, fn command ->
          case dispatch(command, Keyword.put(opts, :idempotent, false)) do
            {:ok, result} -> {:ok, {command, result}}
            {:error, reason} -> {:error, {command, reason}}
          end
        end)

      # エラーがあれば全体を失敗とする
      errors = Enum.filter(results, &match?({:error, _}, &1))

      if Enum.empty?(errors) do
        {:ok, Enum.map(results, fn {:ok, {_cmd, result}} -> result end)}
      else
        {:error, {:batch_failed, errors}}
      end
    end
  end

  # Private functions

  defp validate_command(command) do
    try do
      case Command.validate(command) do
        :ok -> :ok
        {:error, _} = error -> error
      end
    rescue
      Protocol.UndefinedError ->
        {:error, {:invalid_command, "Command must implement Shared.CQRS.Command protocol"}}
    end
  end

  defp validate_all_commands(commands) do
    errors =
      commands
      |> Enum.with_index()
      |> Enum.reduce([], fn {command, index}, acc ->
        case validate_command(command) do
          :ok -> acc
          {:error, reason} -> [{index, reason} | acc]
        end
      end)

    if Enum.empty?(errors) do
      :ok
    else
      {:error, {:validation_failed, Enum.reverse(errors)}}
    end
  end

  defp get_handler(command) do
    try do
      handler = Command.handler(command)

      # ハンドラーが存在することを確認
      if Code.ensure_loaded?(handler) do
        {:ok, handler}
      else
        {:error, {:handler_not_found, handler}}
      end
    rescue
      Protocol.UndefinedError ->
        {:error, {:invalid_command, "Command must implement Shared.CQRS.Command protocol"}}
    end
  end

  defp dispatch_idempotent(command, handler, opts) do
    # べき等性キーを生成
    idempotency_key = generate_idempotency_key(command)
    ttl = IdempotencyKey.ttl_seconds("command")

    IdempotencyStore.execute(
      idempotency_key,
      fn ->
        dispatch_direct(command, handler, opts)
      end,
      ttl: ttl
    )
  end

  defp dispatch_direct(command, handler, opts) do
    start_time = System.monotonic_time()

    # メタデータを準備
    metadata = prepare_metadata(command, opts)

    # Telemetryイベントを発行
    :telemetry.execute(
      [:cqrs, :command, :dispatching],
      %{},
      metadata
    )

    # ハンドラーを実行
    result =
      try do
        if function_exported?(handler, :handle, 2) do
          handler.handle(command, metadata)
        else
          handler.handle(command)
        end
      rescue
        e ->
          Logger.error("Command handler raised an exception: #{inspect(e)}")
          {:error, {:handler_exception, e, __STACKTRACE__}}
      end

    # 実行時間を計測
    duration = System.monotonic_time() - start_time

    # 結果に応じたTelemetryイベントを発行
    case result do
      {:ok, _} = success ->
        :telemetry.execute(
          [:cqrs, :command, :success],
          %{duration: System.convert_time_unit(duration, :native, :millisecond)},
          metadata
        )

        success

      {:error, _} = error ->
        :telemetry.execute(
          [:cqrs, :command, :failure],
          %{duration: System.convert_time_unit(duration, :native, :millisecond)},
          Map.put(metadata, :error, elem(error, 1))
        )

        error

      other ->
        # 予期しない戻り値
        Logger.warning("Command handler returned unexpected value: #{inspect(other)}")
        {:error, {:invalid_handler_response, other}}
    end
  end

  defp generate_idempotency_key(command) do
    aggregate_type = Command.aggregate_type(command)
    command_id = Command.command_id(command)
    command_type = command.__struct__ |> Module.split() |> List.last() |> Macro.underscore()

    # コマンドの重要なフィールドを抽出
    params =
      command
      |> Map.from_struct()
      |> Map.drop([:__struct__, :metadata])

    IdempotencyKey.generate(
      "command",
      "#{aggregate_type}_#{command_id || "new"}",
      command_type,
      params
    )
  end

  defp prepare_metadata(command, opts) do
    %{
      command_type: command.__struct__,
      aggregate_type: Command.aggregate_type(command),
      command_id: Command.command_id(command),
      timestamp: DateTime.utc_now(),
      user_metadata: Keyword.get(opts, :metadata, %{})
    }
  end
end
