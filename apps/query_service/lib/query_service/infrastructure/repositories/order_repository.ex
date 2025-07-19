defmodule QueryService.Infrastructure.Repositories.OrderRepository do
  @moduledoc """
  注文リポジトリ

  注文の Read Model を管理します
  """

  import Ecto.Query
  alias QueryService.Domain.ReadModels.Order
  alias QueryService.Repo

  @doc """
  注文を作成する
  """
  def create(attrs) do
    %Order{}
    |> Order.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  注文を更新する
  """
  def update(id, attrs) do
    case get(id) do
      {:ok, order} ->
        order
        |> Order.changeset(attrs)
        |> Repo.update()

      error ->
        error
    end
  end

  @doc """
  注文を取得する
  """
  def get(id) do
    case Repo.get(Order, id) do
      nil -> {:error, :not_found}
      order -> {:ok, order}
    end
  end

  @doc """
  すべての注文を取得する
  """
  def get_all(filters \\ %{}) do
    query = from(o in Order)

    query =
      Enum.reduce(filters, query, fn
        {:user_id, user_id}, query ->
          from(o in query, where: o.user_id == ^user_id)

        {:status, status}, query ->
          from(o in query, where: o.status == ^status)

        {:sort_by, field}, query ->
          order_by_field(query, field, Map.get(filters, :sort_order, :asc))

        {:limit, limit}, query ->
          from(o in query, limit: ^limit)

        {:offset, offset}, query ->
          from(o in query, offset: ^offset)

        _, query ->
          query
      end)

    {:ok, Repo.all(query)}
  end

  @doc """
  ユーザーの注文を取得する
  """
  def get_by_user(user_id, filters \\ %{}) do
    filters = Map.put(filters, :user_id, user_id)
    get_all(filters)
  end

  @doc """
  注文を検索する
  """
  def search(filters \\ %{}) do
    query = from(o in Order)

    query =
      Enum.reduce(filters, query, fn
        {:user_id, user_id}, query ->
          from(o in query, where: o.user_id == ^user_id)

        {:status, status}, query ->
          from(o in query, where: o.status == ^status)

        {:from_date, from_date}, query ->
          from(o in query, where: o.inserted_at >= ^from_date)

        {:to_date, to_date}, query ->
          from(o in query, where: o.inserted_at <= ^to_date)

        {:min_amount, min_amount}, query ->
          from(o in query, where: o.total_amount >= ^min_amount)

        {:max_amount, max_amount}, query ->
          from(o in query, where: o.total_amount <= ^max_amount)

        {:sort_by, field}, query ->
          order_by_field(query, field, Map.get(filters, :sort_order, :asc))

        {:limit, limit}, query ->
          from(o in query, limit: ^limit)

        {:offset, offset}, query ->
          from(o in query, offset: ^offset)

        _, query ->
          query
      end)

    {:ok, Repo.all(query)}
  end

  @doc """
  注文を削除する
  """
  def delete(id) do
    case get(id) do
      {:ok, order} ->
        case Repo.delete(order) do
          {:ok, _} -> :ok
          error -> error
        end

      error ->
        error
    end
  end

  @doc """
  すべての注文を削除する
  """
  def delete_all do
    {count, _} = Repo.delete_all(Order)
    {:ok, count}
  end

  # Private functions

  defp order_by_field(query, field, direction) do
    case field do
      "created_at" -> from(o in query, order_by: [{^direction, o.inserted_at}])
      "total_amount" -> from(o in query, order_by: [{^direction, o.total_amount}])
      "status" -> from(o in query, order_by: [{^direction, o.status}])
      _ -> query
    end
  end
end
