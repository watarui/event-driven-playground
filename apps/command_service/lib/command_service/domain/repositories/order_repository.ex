defmodule CommandService.Domain.Repositories.OrderRepository do
  @moduledoc """
  注文リポジトリ

  注文アグリゲートの永続化を担当する。
  """

  use Shared.Infrastructure.EventSourcedRepository,
    aggregate: CommandService.Domain.Aggregates.OrderAggregate,
    aggregate_type: :order

  require Logger
  alias CommandService.Domain.Aggregates.OrderAggregate

  # ドメイン固有のクエリメソッドを追加

  @doc """
  ユーザーIDで注文を検索する

  Note: これは Read Model から取得すべきだが、例として実装
  """
  def find_by_user_id(_user_id) do
    Logger.warning("find_by_user_id should use Read Model instead of Event Store")
    {:error, :use_read_model}
  end

  @doc """
  注文ステータスで検索する

  Note: これは Read Model から取得すべきだが、例として実装
  """
  def find_by_status(_status) do
    Logger.warning("find_by_status should use Read Model instead of Event Store")
    {:error, :use_read_model}
  end

  @doc """
  注文を確定する
  """
  def confirm_order(order_id) do
    with {:ok, order} <- find_by_id(order_id),
         {:ok, updated_order} <- OrderAggregate.confirm(order) do
      save(updated_order)
    end
  end

  @doc """
  注文をキャンセルする
  """
  def cancel_order(order_id, reason) do
    with {:ok, order} <- find_by_id(order_id),
         {:ok, updated_order} <- OrderAggregate.cancel(order, reason) do
      save(updated_order)
    end
  end

  @doc """
  削除（注文は削除できない）
  """
  @impl true
  def delete(_id) do
    {:error, :not_allowed}
  end


  @doc """
  注文が存在するか確認する
  """
  @impl true
  def exists?(order_id) do
    case find_by_id(order_id) do
      {:ok, _} -> true
      {:error, :not_found} -> false
      _ -> false
    end
  end

  @doc """
  複数のIDで注文を取得する
  
  Note: イベントソーシングでは非効率なため、Read Model の使用を推奨
  """
  @impl true
  def find_by_ids(ids) when is_list(ids) do
    Logger.warning("find_by_ids/1 is not efficient for event-sourced repositories, use Read Model")
    
    results =
      ids
      |> Enum.map(&find_by_id/1)
      |> Enum.reduce({[], []}, fn
        {:ok, order}, {orders, errors} ->
          {[order | orders], errors}

        {:error, error}, {orders, errors} ->
          {orders, [error | errors]}
      end)

    case results do
      {orders, []} -> {:ok, Enum.reverse(orders)}
      {_, errors} -> {:error, {:partial_failure, errors}}
    end
  end
end
