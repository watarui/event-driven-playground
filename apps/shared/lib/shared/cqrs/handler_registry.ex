defmodule Shared.CQRS.HandlerRegistry do
  @moduledoc """
  コマンド/クエリハンドラーの自動登録と管理

  アプリケーション起動時にハンドラーを自動的に発見し、
  登録する機能を提供する。
  """

  use GenServer
  require Logger

  @type handler_type :: :command | :query
  @type handler_info :: %{
          module: module(),
          type: handler_type,
          handles: [module()],
          metadata: map()
        }

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  ハンドラーを登録する
  """
  @spec register_handler(module(), handler_type(), keyword()) :: :ok | {:error, term()}
  def register_handler(handler_module, type, opts \\ []) do
    GenServer.call(__MODULE__, {:register_handler, handler_module, type, opts})
  end

  @doc """
  コマンド/クエリタイプに対するハンドラーを取得する
  """
  @spec get_handler_for(module()) :: {:ok, module()} | {:error, :not_found}
  def get_handler_for(command_or_query_type) do
    GenServer.call(__MODULE__, {:get_handler_for, command_or_query_type})
  end

  @doc """
  すべての登録済みハンドラーを取得する
  """
  @spec list_handlers() :: [handler_info()]
  def list_handlers do
    GenServer.call(__MODULE__, :list_handlers)
  end

  @doc """
  アプリケーション内のハンドラーを自動発見して登録する
  """
  @spec auto_discover(atom()) :: {:ok, non_neg_integer()} | {:error, term()}
  def auto_discover(app_name) do
    GenServer.call(__MODULE__, {:auto_discover, app_name})
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    # 自動発見が有効な場合
    if Keyword.get(opts, :auto_discover, true) do
      send(self(), :auto_discover_all)
    end

    state = %{
      # handler_module -> handler_info
      handlers: %{},
      # command/query_type -> handler_module
      type_mapping: %{},
      # 統計
      stats: %{
        command_handlers: 0,
        query_handlers: 0,
        total_registered: 0
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:register_handler, handler_module, type, opts}, _from, state) do
    case do_register_handler(handler_module, type, opts, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:get_handler_for, type}, _from, state) do
    case Map.get(state.type_mapping, type) do
      nil ->
        {:reply, {:error, :not_found}, state}

      handler_module ->
        {:reply, {:ok, handler_module}, state}
    end
  end

  @impl true
  def handle_call(:list_handlers, _from, state) do
    handlers = Map.values(state.handlers)
    {:reply, handlers, state}
  end

  @impl true
  def handle_call({:auto_discover, app_name}, _from, state) do
    case discover_handlers_in_app(app_name) do
      {:ok, handlers} ->
        {new_state, registered_count} =
          Enum.reduce(handlers, {state, 0}, fn {module, type}, {acc_state, count} ->
            case do_register_handler(module, type, [], acc_state) do
              {:ok, updated_state} -> {updated_state, count + 1}
              {:error, _} -> {acc_state, count}
            end
          end)

        {:reply, {:ok, registered_count}, new_state}

      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_info(:auto_discover_all, state) do
    # すべてのロードされたアプリケーションでハンドラーを発見
    apps = [:command_service, :query_service]

    new_state =
      Enum.reduce(apps, state, fn app, acc_state ->
        case discover_handlers_in_app(app) do
          {:ok, handlers} ->
            Enum.reduce(handlers, acc_state, fn {module, type}, inner_state ->
              case do_register_handler(module, type, [], inner_state) do
                {:ok, updated_state} -> updated_state
                {:error, _} -> inner_state
              end
            end)

          {:error, _} ->
            acc_state
        end
      end)

    Logger.info("Auto-discovered #{map_size(new_state.handlers)} handlers")

    {:noreply, new_state}
  end

  # Private functions

  defp do_register_handler(handler_module, type, opts, state) do
    with :ok <- validate_handler(handler_module, type),
         {:ok, handled_types} <- get_handled_types(handler_module, type) do
      handler_info = %{
        module: handler_module,
        type: type,
        handles: handled_types,
        metadata: Keyword.get(opts, :metadata, %{})
      }

      # ハンドラー情報を保存
      new_handlers = Map.put(state.handlers, handler_module, handler_info)

      # タイプマッピングを更新
      new_type_mapping =
        Enum.reduce(handled_types, state.type_mapping, fn handled_type, acc ->
          Map.put(acc, handled_type, handler_module)
        end)

      # 統計を更新
      stats_key = if type == :command, do: :command_handlers, else: :query_handlers

      new_stats =
        state.stats
        |> Map.update(stats_key, 1, &(&1 + 1))
        |> Map.update(:total_registered, 1, &(&1 + 1))

      new_state = %{
        state
        | handlers: new_handlers,
          type_mapping: new_type_mapping,
          stats: new_stats
      }

      Logger.info("Registered #{type} handler: #{inspect(handler_module)}")

      {:ok, new_state}
    end
  end

  defp validate_handler(handler_module, type) do
    cond do
      not Code.ensure_loaded?(handler_module) ->
        {:error, {:module_not_found, handler_module}}

      type == :command && not function_exported?(handler_module, :handle, 1) &&
          not function_exported?(handler_module, :handle, 2) ->
        {:error, {:invalid_handler, "Command handler must export handle/1 or handle/2"}}

      type == :query && not function_exported?(handler_module, :handle, 1) &&
          not function_exported?(handler_module, :handle, 2) ->
        {:error, {:invalid_handler, "Query handler must export handle/1 or handle/2"}}

      true ->
        :ok
    end
  end

  defp get_handled_types(handler_module, type) do
    # ハンドラーモジュールから処理するタイプを取得
    cond do
      function_exported?(handler_module, :handles, 0) ->
        {:ok, handler_module.handles()}

      function_exported?(handler_module, :__handles__, 0) ->
        {:ok, handler_module.__handles__()}

      true ->
        # モジュール名から推測
        infer_handled_types(handler_module, type)
    end
  end

  defp infer_handled_types(handler_module, _type) do
    # モジュール名からコマンド/クエリタイプを推測
    # 例: OrderCommandHandler -> OrderCommands.* を処理
    module_name = handler_module |> Module.split() |> List.last()

    cond do
      String.ends_with?(module_name, "CommandHandler") ->
        # TODO: より洗練された推測ロジック
        {:ok, []}

      String.ends_with?(module_name, "QueryHandler") ->
        {:ok, []}

      true ->
        {:ok, []}
    end
  end

  defp discover_handlers_in_app(app_name) do
    try do
      # アプリケーションのモジュールを取得
      {:ok, modules} = :application.get_key(app_name, :modules)

      handlers =
        modules
        |> Enum.filter(&handler_module?/1)
        |> Enum.map(fn module ->
          type = infer_handler_type(module)
          {module, type}
        end)
        |> Enum.filter(fn {_, type} -> type != nil end)

      {:ok, handlers}
    rescue
      _ -> {:error, {:app_not_found, app_name}}
    end
  end

  defp handler_module?(module) do
    module_name = module |> Module.split() |> List.last()

    String.ends_with?(module_name, "CommandHandler") ||
      String.ends_with?(module_name, "QueryHandler")
  end

  defp infer_handler_type(module) do
    module_name = module |> Module.split() |> List.last()

    cond do
      String.ends_with?(module_name, "CommandHandler") -> :command
      String.ends_with?(module_name, "QueryHandler") -> :query
      true -> nil
    end
  end
end
