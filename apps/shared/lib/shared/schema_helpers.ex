defmodule Shared.SchemaHelpers do
  @moduledoc """
  Ecto スキーマのプレフィックス管理ヘルパー

  各スキーマで手動で @schema_prefix を設定する代わりに、
  このモジュールのマクロを使用することで、一元的に管理できます。
  """

  @doc """
  event_store スキーマを使用する Ecto スキーマ用のマクロ

  ## 使用例

      defmodule MyModule do
        use Ecto.Schema
        import Shared.SchemaHelpers
        
        event_store_schema()
        
        schema "events" do
          # ...
        end
      end
  """
  defmacro event_store_schema do
    quote do
      @schema_prefix "event_store"
    end
  end

  @doc """
  command スキーマを使用する Ecto スキーマ用のマクロ
  """
  defmacro command_schema do
    quote do
      @schema_prefix "command"
    end
  end

  @doc """
  query スキーマを使用する Ecto スキーマ用のマクロ
  """
  defmacro query_schema do
    quote do
      @schema_prefix "query"
    end
  end

  @doc """
  スキーマプレフィックスを動的に設定するヘルパー

  ## 使用例

      query = from e in Event, select: e
      |> put_schema_prefix(:event_store)
  """
  def put_schema_prefix(query, prefix) when is_atom(prefix) do
    put_schema_prefix(query, to_string(prefix))
  end

  def put_schema_prefix(query, prefix) when is_binary(prefix) do
    %{query | prefix: prefix}
  end

  @doc """
  スキーマ名を完全修飾名で返す

  ## 使用例

      qualified_table(:event_store, :events)
      # => "event_store.events"
  """
  def qualified_table(schema, table) when is_atom(schema) and is_atom(table) do
    qualified_table(to_string(schema), to_string(table))
  end

  def qualified_table(schema, table) when is_binary(schema) and is_binary(table) do
    "#{schema}.#{table}"
  end

  @doc """
  SQL クエリでスキーマプレフィックスを自動的に適用するヘルパー

  ## 使用例

      with_schema_prefix(:event_store, "SELECT * FROM events")
      # => "SELECT * FROM event_store.events"
  """
  def with_schema_prefix(schema, sql) when is_atom(schema) do
    with_schema_prefix(to_string(schema), sql)
  end

  def with_schema_prefix(schema, sql) when is_binary(schema) and is_binary(sql) do
    # 簡易的な実装。より複雑なケースでは SQL パーサーが必要
    sql
    |> String.replace(~r/FROM\s+(\w+)/i, "FROM #{schema}.\\1")
    |> String.replace(~r/JOIN\s+(\w+)/i, "JOIN #{schema}.\\1")
    |> String.replace(~r/INTO\s+(\w+)/i, "INTO #{schema}.\\1")
    |> String.replace(~r/UPDATE\s+(\w+)/i, "UPDATE #{schema}.\\1")
    |> String.replace(~r/DELETE\s+FROM\s+(\w+)/i, "DELETE FROM #{schema}.\\1")
  end
end
