defmodule CommandService.Domain.Repositories.ProductRepository do
  @moduledoc """
  商品リポジトリのビヘイビア定義

  商品アグリゲートの永続化に関するインターフェースを定義します。
  """

  alias CommandService.Domain.Aggregates.ProductAggregate

  @doc """
  商品IDで商品を取得する
  """
  @callback get(String.t() | binary()) :: {:ok, ProductAggregate.t()} | {:error, :not_found}

  @doc """
  商品を保存する
  """
  @callback save(ProductAggregate.t()) :: {:ok, ProductAggregate.t()} | {:error, term()}

  @doc """
  商品が存在するか確認する
  """
  @callback exists?(String.t() | binary()) :: boolean()

  @doc """
  商品名で検索する
  """
  @callback find_by_name(String.t()) :: {:ok, ProductAggregate.t()} | {:error, :not_found}

  @doc """
  在庫を更新する
  """
  @callback update_stock(String.t() | binary(), integer()) ::
              {:ok, ProductAggregate.t()} | {:error, term()}

  @doc """
  在庫をチェックする
  """
  @callback check_stock(String.t() | binary(), integer()) :: {:ok, boolean()} | {:error, term()}
end
