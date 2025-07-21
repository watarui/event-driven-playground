defmodule Shared.Infrastructure.Repository do
  @moduledoc """
  リポジトリのビヘイビア定義
  
  PostgreSQL と Firestore の両方で実装可能な共通インターフェースを提供します。
  """

  @type entity :: map()
  @type id :: String.t()
  @type error :: {:error, term()}

  @doc """
  エンティティを保存
  """
  @callback save(collection :: String.t(), id :: id(), entity :: entity()) ::
              {:ok, entity()} | error()

  @doc """
  ID でエンティティを取得
  """
  @callback get(collection :: String.t(), id :: id()) ::
              {:ok, entity()} | {:error, :not_found} | error()

  @doc """
  複数のエンティティを取得
  """
  @callback list(collection :: String.t(), opts :: keyword()) ::
              {:ok, [entity()]} | error()

  @doc """
  エンティティを削除
  """
  @callback delete(collection :: String.t(), id :: id()) ::
              :ok | error()

  @doc """
  トランザクション実行
  """
  @callback transaction(fun :: function()) ::
              {:ok, any()} | error()

  @doc """
  クエリ実行（フィルタリング）
  """
  @callback query(collection :: String.t(), filters :: keyword(), opts :: keyword()) ::
              {:ok, [entity()]} | error()
end