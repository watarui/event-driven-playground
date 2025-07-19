defmodule Shared.Infrastructure.Idempotency.IdempotentCommandHandler do
  @moduledoc """
  コマンドハンドラーにべき等性を追加するヘルパーモジュール

  ## 使用例

      defmodule MyCommandHandler do
        use Shared.Infrastructure.Idempotency.IdempotentCommandHandler
        
        def handle(%CreateOrder{} = command) do
          with_idempotency command, "create_order" do
            # 実際の処理
            {:ok, order}
          end
        end
      end
  """

  alias Shared.Infrastructure.Idempotency.{IdempotencyKey, IdempotencyStore}

  defmacro __using__(_opts) do
    quote do
      import Shared.Infrastructure.Idempotency.IdempotentCommandHandler
      require Logger
    end
  end

  @doc """
  コマンドをべき等に実行する

  ## Parameters
  - `command` - 実行するコマンド
  - `operation` - 操作名
  - `opts` - オプション
    - `:ttl` - キャッシュの有効期限（秒）
    - `:key_fields` - べき等性キーに使用するフィールド
  - `do_block` - 実際の処理

  ## Examples
      with_idempotency command, "create_order", ttl: 7200 do
        # 処理
      end
  """
  defmacro with_idempotency(command, operation, opts \\ [], do: do_block) do
    quote do
      command_val = unquote(command)
      operation_val = unquote(operation)
      opts_val = unquote(opts)

      # べき等性キーを生成
      key = generate_idempotency_key(command_val, operation_val, opts_val)

      # TTLを取得
      ttl = Keyword.get(opts_val, :ttl) || IdempotencyKey.ttl_seconds("command")

      # べき等に実行
      IdempotencyStore.execute(
        key,
        fn ->
          unquote(do_block)
        end,
        ttl: ttl
      )
    end
  end

  @doc """
  コマンドからべき等性キーを生成する
  """
  def generate_idempotency_key(command, operation, opts \\ []) do
    key_fields = Keyword.get(opts, :key_fields, [:id])

    # コマンドから指定されたフィールドを抽出
    params = extract_key_fields(command, key_fields)

    # アグリゲートIDを取得（あれば）
    identifier = get_aggregate_id(command) || generate_command_id(command)

    IdempotencyKey.generate("command", identifier, operation, params)
  end

  defp extract_key_fields(command, fields) do
    command_map = Map.from_struct(command)

    fields
    |> Enum.reduce(%{}, fn field, acc ->
      case Map.get(command_map, field) do
        nil -> acc
        value -> Map.put(acc, field, normalize_value(value))
      end
    end)
  end

  # EntityIdなどの値オブジェクト
  defp normalize_value(%{value: v}), do: v
  defp normalize_value(v), do: v

  defp get_aggregate_id(command) do
    cond do
      Map.has_key?(command, :aggregate_id) && command.aggregate_id ->
        normalize_value(command.aggregate_id)

      Map.has_key?(command, :id) && command.id ->
        normalize_value(command.id)

      true ->
        nil
    end
  end

  defp generate_command_id(command) do
    # コマンドの型名とタイムスタンプからIDを生成
    type_name =
      command.__struct__
      |> Module.split()
      |> List.last()
      |> Macro.underscore()

    timestamp = System.unique_integer([:positive, :monotonic])
    "#{type_name}_#{timestamp}"
  end
end
