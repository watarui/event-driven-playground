defmodule ClientService.GraphQL.Types.Category do
  @moduledoc """
  カテゴリ関連の GraphQL 型定義
  """

  use Absinthe.Schema.Notation

  @desc "カテゴリ"
  object :category do
    field(:id, non_null(:id))
    field(:name, non_null(:string))
    field(:description, :string)
    field(:parent_id, :id)
    field(:active, :boolean)
    field(:product_count, :integer)

    field :products, list_of(:product) do
      resolve(fn category, _args, _resolution ->
        # カスタム Dataloader を使用したバッチ取得
        # 実際の実装では、リゾルバー内で RemoteQueryBus を使用
        alias ClientService.Infrastructure.RemoteQueryBus

        query = %{
          __struct__: "QueryService.Application.Queries.ProductQueries.ListProducts",
          query_type: "product.list",
          category_id: category.id,
          limit: 100,
          offset: 0,
          metadata: nil
        }

        case RemoteQueryBus.send_query(query) do
          {:ok, products} ->
            {:ok, products || []}

          {:error, _reason} ->
            {:ok, []}
        end
      end)
    end

    field(:created_at, non_null(:datetime))
    field(:updated_at, non_null(:datetime))
  end

  @desc "カテゴリ作成入力"
  input_object :create_category_input do
    field(:name, non_null(:string))
    field(:description, :string)
    field(:parent_id, :id)
  end

  @desc "カテゴリ更新入力"
  input_object :update_category_input do
    field(:name, :string)
    field(:description, :string)
    field(:parent_id, :id)
  end
end
