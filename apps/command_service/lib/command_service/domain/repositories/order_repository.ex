defmodule CommandService.Domain.Repositories.OrderRepository do
  @moduledoc """
  注文リポジトリ

  注文アグリゲートの永続化を担当する。
  """

  @behaviour Shared.Domain.Repository

  require Logger
  alias CommandService.Domain.Aggregates.OrderAggregate

  @impl true
  def aggregate_type, do: :order

  @impl true
  def find_by_id(order_id) do
    # 実装は Infrastructure 層に委譲
    CommandService.Infrastructure.Repositories.OrderRepository.find_by_id(order_id)
  end

  @impl true
  def save(order) do
    # 実装は Infrastructure 層に委譲
    CommandService.Infrastructure.Repositories.OrderRepository.save(order)
  end

  @impl true
  def find_by_ids(ids) do
    # 実装は Infrastructure 層に委譲
    CommandService.Infrastructure.Repositories.OrderRepository.find_by_ids(ids)
  end

  @impl true
  def find_by(criteria) do
    # 実装は Infrastructure 層に委譲
    CommandService.Infrastructure.Repositories.OrderRepository.find_by(criteria)
  end

  @impl true
  def all(_opts \\ []) do
    # イベントソーシングでは全件取得は非効率
    Logger.warning("all/1 is not efficient for event-sourced repositories")
    {:error, :not_supported}
  end

  @impl true
  def count(_opts \\ []) do
    # イベントソーシングでは件数取得は非効率
    Logger.warning("count/1 is not efficient for event-sourced repositories")
    {:error, :not_supported}
  end

  @impl true
  def exists?(order_id) do
    # 実装は Infrastructure 層に委譲
    CommandService.Infrastructure.Repositories.OrderRepository.exists?(order_id)
  end

  @impl true
  def transaction(fun) do
    # 実装は Infrastructure 層に委譲
    CommandService.Infrastructure.Repositories.OrderRepository.transaction(fun)
  end

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


end
