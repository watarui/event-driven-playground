defmodule CommandService.Infrastructure.RepositoryFactory do
  @moduledoc """
  リポジトリファクトリ
  
  環境に応じて適切なリポジトリ実装を返します。
  """

  alias Shared.Config

  @doc """
  指定されたアグリゲートタイプのリポジトリモジュールを取得
  """
  def get_repository(aggregate_type) do
    case Config.database_adapter() do
      :firestore ->
        get_firestore_repository(aggregate_type)
      _ ->
        get_postgres_repository(aggregate_type)
    end
  end

  defp get_firestore_repository(aggregate_type) do
    case aggregate_type do
      :order -> CommandService.Infrastructure.Firestore.OrderRepository
      :product -> CommandService.Infrastructure.Firestore.ProductRepository
      :category -> CommandService.Infrastructure.Firestore.CategoryRepository
      _ -> raise "Unknown aggregate type: #{aggregate_type}"
    end
  end

  defp get_postgres_repository(aggregate_type) do
    case aggregate_type do
      :order -> CommandService.Infrastructure.Repositories.OrderRepository
      :product -> CommandService.Infrastructure.Repositories.ProductRepository
      :category -> CommandService.Infrastructure.Repositories.CategoryRepository
      _ -> raise "Unknown aggregate type: #{aggregate_type}"
    end
  end
end