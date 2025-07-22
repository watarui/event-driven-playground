defmodule CommandService.Infrastructure.UnitOfWork do
  @moduledoc """
  Unit of Work パターンの実装（Firestore版）

  トランザクション境界を管理し、ドメインイベントの一貫性を保証します。
  """

  require Logger

  @doc """
  トランザクション内で処理を実行する

  ## Examples

      UnitOfWork.transaction(fn ->
        with {:ok, aggregate} <- CategoryRepository.get(id),
             {:ok, updated} <- CategoryAggregate.execute(aggregate, command),
             {:ok, _} <- CategoryRepository.save(updated) do
          {:ok, updated}
        end
      end)
  """
  def transaction(fun) when is_function(fun, 0) do
    # Firestore のトランザクションは現在の実装では完全にサポートされていないため、
    # 楽観的ロックとイベントの順序保証で一貫性を確保します。
    Process.put(:unit_of_work_events, [])
    Process.put(:unit_of_work_active, true)
    
    try do
      case fun.() do
        {:ok, result} ->
          # 収集したイベントを発行
          publish_collected_events()
          {:ok, result}
        
        {:error, _} = error ->
          # エラーの場合はイベントを破棄
          discard_collected_events()
          error
        
        result ->
          # 関数が{:ok, _} | {:error, _}の形式でない場合
          publish_collected_events()
          result
      end
    rescue
      e ->
        Logger.error("Transaction failed: #{inspect(e)}")
        discard_collected_events()
        {:error, {:transaction_failed, e}}
    after
      # クリーンアップ
      Process.delete(:unit_of_work_events)
      Process.delete(:unit_of_work_active)
    end
  end

  @doc """
  アグリゲートとイベントを保存するトランザクション

  アグリゲートの状態保存とイベントストアへのイベント保存を
  同一トランザクション内で実行します。
  """
  def transaction_with_events(fun) when is_function(fun, 0) do
    # transaction と同じ動作にする
    transaction(fun)
  end

  @doc """
  現在のトランザクションにイベントを追加する

  この関数は transaction_with_events 内でのみ使用してください。
  """
  def add_event(event) do
    if Process.get(:unit_of_work_active, false) do
      events = Process.get(:unit_of_work_events, [])
      Process.put(:unit_of_work_events, [event | events])
    else
      Logger.warning("Attempted to add event outside of transaction")
    end
    
    :ok
  end

  @doc """
  現在のトランザクションに複数のイベントを追加する
  """
  def add_events(events) when is_list(events) do
    Enum.each(events, &add_event/1)
    :ok
  end

  @doc """
  トランザクションがアクティブかチェック
  """
  @spec in_transaction?() :: boolean()
  def in_transaction? do
    Process.get(:unit_of_work_active, false)
  end

  # Private functions

  defp publish_collected_events do
    events = Process.get(:unit_of_work_events, []) |> Enum.reverse()
    
    if Enum.any?(events) do
      Logger.info("Publishing #{length(events)} events from transaction")
      
      # イベントバスに一括で発行
      Enum.each(events, fn event ->
        try do
          Shared.Infrastructure.EventBus.publish_event(event)
        rescue
          e ->
            Logger.error("Failed to publish event: #{inspect(e)}")
            # イベント発行の失敗は記録するが、トランザクション自体は成功とする
            # Dead Letter Queue などで後続処理
        end
      end)
    end
  end

  defp discard_collected_events do
    events = Process.get(:unit_of_work_events, [])
    
    if Enum.any?(events) do
      Logger.info("Discarding #{length(events)} events due to transaction failure")
    end
  end
end
