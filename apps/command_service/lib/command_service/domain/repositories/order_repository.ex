defmodule CommandService.Domain.Repositories.OrderRepository do
  @moduledoc """
  注文リポジトリ

  注文アグリゲートの永続化を担当する。
  """

  use Shared.Infrastructure.EventSourcedRepository,
    aggregate: CommandService.Domain.Aggregates.OrderAggregate,
    aggregate_type: :order

  alias CommandService.Domain.Aggregates.OrderAggregate
  alias Shared.Domain.ValueObjects.EntityId

  # ドメイン固有のクエリメソッドを追加

  @doc """
  ユーザーIDで注文を検索する

  Note: これは Read Model から取得すべきだが、例として実装
  """
  def find_by_user_id(user_id) do
    Logger.warning("find_by_user_id should use Read Model instead of Event Store")
    {:error, :use_read_model}
  end

  @doc """
  注文ステータスで検索する

  Note: これは Read Model から取得すべきだが、例として実装
  """
  def find_by_status(status) do
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
end
