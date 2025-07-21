defmodule CommandService.Domain.Repositories.CategoryRepository do
  @moduledoc """
  カテゴリリポジトリのビヘイビア定義

  カテゴリアグリゲートの永続化に関するインターフェースを定義します。
  """

  alias CommandService.Domain.Aggregates.CategoryAggregate

  @doc """
  カテゴリIDでカテゴリを取得する
  """
  @callback get(String.t() | binary()) :: {:ok, CategoryAggregate.t()} | {:error, :not_found}

  @doc """
  カテゴリを保存する
  """
  @callback save(CategoryAggregate.t()) :: {:ok, CategoryAggregate.t()} | {:error, term()}

  @doc """
  カテゴリが存在するか確認する
  """
  @callback exists?(String.t() | binary()) :: boolean()

  @doc """
  カテゴリ名で検索する
  """
  @callback find_by_name(String.t()) :: {:ok, CategoryAggregate.t()} | {:error, :not_found}

  @doc """
  子カテゴリが存在するか確認する
  """
  @callback has_children?(String.t() | binary()) :: boolean()

  @doc """
  カテゴリに商品が存在するか確認する
  """
  @callback has_products?(String.t() | binary()) :: boolean()
end