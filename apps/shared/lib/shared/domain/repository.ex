defmodule Shared.Domain.Repository do
  @moduledoc """
  リポジトリインターフェースの定義

  すべてのリポジトリが実装すべき標準的な操作を定義する。
  """

  @type aggregate :: struct()
  @type aggregate_id :: String.t() | Shared.Domain.ValueObjects.EntityId.t()
  @type error :: {:error, atom() | map()}

  @doc """
  アグリゲートの型を返す
  """
  @callback aggregate_type() :: atom()

  @doc """
  ID でアグリゲートを取得する
  """
  @callback find_by_id(aggregate_id()) :: {:ok, aggregate()} | error()

  @doc """
  複数の ID でアグリゲートを取得する
  """
  @callback find_by_ids([aggregate_id()]) :: {:ok, [aggregate()]} | error()

  @doc """
  アグリゲートを保存する
  """
  @callback save(aggregate()) :: {:ok, aggregate()} | error()

  @doc """
  アグリゲートを削除する
  """
  @callback delete(aggregate_id()) :: :ok | error()

  @doc """
  条件に一致するアグリゲートを検索する
  """
  @callback find_by(keyword()) :: {:ok, [aggregate()]} | error()

  @doc """
  すべてのアグリゲートを取得する
  """
  @callback all(keyword()) :: {:ok, [aggregate()]} | error()

  @doc """
  アグリゲートの数を取得する
  """
  @callback count(keyword()) :: {:ok, non_neg_integer()} | error()

  @doc """
  アグリゲートが存在するかチェックする
  """
  @callback exists?(aggregate_id()) :: boolean()

  @doc """
  トランザクション内で操作を実行する
  """
  @callback transaction((-> any())) :: {:ok, any()} | error()

  # オプショナルなコールバック

  @doc """
  バッチ挿入を実行する
  """
  @callback insert_all([map()]) :: {:ok, non_neg_integer()} | error()
  @optional_callbacks insert_all: 1

  @doc """
  条件に一致するアグリゲートを更新する
  """
  @callback update_by(keyword(), map()) :: {:ok, non_neg_integer()} | error()
  @optional_callbacks update_by: 2

  @doc """
  条件に一致するアグリゲートを削除する
  """
  @callback delete_by(keyword()) :: {:ok, non_neg_integer()} | error()
  @optional_callbacks delete_by: 1

  defmacro __using__(_opts) do
    quote do
      @behaviour Shared.Domain.Repository

      import Shared.Domain.Repository

      # デフォルトの実装を提供

      @impl true
      def exists?(aggregate_id) do
        case find_by_id(aggregate_id) do
          {:ok, _} -> true
          {:error, :not_found} -> false
          _ -> false
        end
      end

      @impl true
      def find_by_ids(ids) when is_list(ids) do
        results =
          ids
          |> Enum.map(&find_by_id/1)
          |> Enum.reduce({[], []}, fn
            {:ok, aggregate}, {aggregates, errors} ->
              {[aggregate | aggregates], errors}

            {:error, error}, {aggregates, errors} ->
              {aggregates, [error | errors]}
          end)

        case results do
          {aggregates, []} -> {:ok, Enum.reverse(aggregates)}
          {_, errors} -> {:error, {:partial_failure, errors}}
        end
      end

      @impl true
      def all(opts \\ []) do
        find_by([], opts)
      end

      @impl true
      def count(opts \\ []) do
        case all(opts) do
          {:ok, aggregates} -> {:ok, length(aggregates)}
          error -> error
        end
      end

      # オーバーライド可能にする
      defoverridable exists?: 1, find_by_ids: 1, all: 1, count: 1
    end
  end
end
