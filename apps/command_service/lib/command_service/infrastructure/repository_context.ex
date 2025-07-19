defmodule CommandService.Infrastructure.RepositoryContext do
  @moduledoc """
  リポジトリコンテキスト

  アグリゲートタイプに基づいて適切なリポジトリを返します。
  依存性注入パターンを使用してテスト可能性を確保します。
  """

  alias CommandService.Infrastructure.Repositories.{
    CategoryRepository,
    ProductRepository,
    OrderRepository
  }

  @type aggregate_type :: :category | :product | :order
  @type repository :: module()

  @repositories %{
    category: CategoryRepository,
    product: ProductRepository,
    order: OrderRepository
  }

  @doc """
  アグリゲートタイプに対応するリポジトリモジュールを取得する

  ## Examples

      iex> RepositoryContext.get_repository(:category)
      CategoryRepository

      iex> RepositoryContext.get_repository(:product)
      ProductRepository
  """
  @spec get_repository(aggregate_type()) :: {:ok, repository()} | {:error, :repository_not_found}
  def get_repository(aggregate_type) when is_atom(aggregate_type) do
    case Map.get(@repositories, aggregate_type) do
      nil -> {:error, :repository_not_found}
      repository -> {:ok, repository}
    end
  end

  @doc """
  アグリゲートタイプに対応するリポジトリモジュールを取得する（例外版）

  ## Examples

      iex> RepositoryContext.get_repository!(:category)
      CategoryRepository
  """
  @spec get_repository!(aggregate_type()) :: repository()
  def get_repository!(aggregate_type) when is_atom(aggregate_type) do
    case get_repository(aggregate_type) do
      {:ok, repository} ->
        repository

      {:error, :repository_not_found} ->
        raise ArgumentError, "Repository not found for aggregate type: #{aggregate_type}"
    end
  end

  @doc """
  登録されているすべてのアグリゲートタイプを取得する
  """
  @spec registered_types() :: [aggregate_type()]
  def registered_types do
    Map.keys(@repositories)
  end

  @doc """
  アグリゲートタイプが登録されているか確認する
  """
  @spec registered?(aggregate_type()) :: boolean()
  def registered?(aggregate_type) do
    Map.has_key?(@repositories, aggregate_type)
  end
end
