defmodule QueryService.Infrastructure.RepositoryFactory do
  @moduledoc """
  リポジトリファクトリ
  
  環境に応じて適切なリポジトリ実装を返します。
  """

  alias Shared.Config

  @doc """
  指定されたエンティティタイプのリポジトリモジュールを取得
  """
  def get_repository(entity_type) do
    case Config.database_adapter() do
      :firestore ->
        get_firestore_repository(entity_type)
      _ ->
        get_postgres_repository(entity_type)
    end
  end

  defp get_firestore_repository(entity_type) do
    case entity_type do
      :order -> QueryService.Infrastructure.Firestore.OrderRepository
      :product -> QueryService.Infrastructure.Firestore.ProductRepository
      :category -> QueryService.Infrastructure.Firestore.CategoryRepository
      _ -> raise "Unknown entity type: #{entity_type}"
    end
  end

  defp get_postgres_repository(entity_type) do
    case entity_type do
      :order -> QueryService.Infrastructure.Repositories.OrderRepository
      :product -> QueryService.Infrastructure.Repositories.ProductRepository
      :category -> QueryService.Infrastructure.Repositories.CategoryRepository
      _ -> raise "Unknown entity type: #{entity_type}"
    end
  end
end