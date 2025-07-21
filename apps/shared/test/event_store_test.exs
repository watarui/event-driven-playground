defmodule Shared.Infrastructure.EventStore.EventStoreTest do
  @moduledoc """
  イベントストアの基本機能テスト
  """

  use ExUnit.Case, async: false

  alias Shared.Infrastructure.EventStore.{
    EventStore,
    Repo
  }

  alias Shared.Domain.ValueObjects.{EntityId, CategoryName}
  alias Shared.Domain.Events.CategoryEvents.{CategoryCreated, CategoryUpdated}

  setup do
    # テストデータをクリーンアップ
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    
    # CircuitBreakerプロセスに接続を許可
    case Registry.lookup(Shared.CircuitBreakerRegistry, :event_store) do
      [{pid, _}] -> 
        Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)
      [] -> 
        :ok
    end
    
    :ok
  end

  describe "イベントストア基本機能" do
    test "イベントの保存と取得" do
      aggregate_id = EntityId.generate().value
      category_id = EntityId.generate()

      # テストイベント
      events = [
        CategoryCreated.new(%{
          id: category_id,
          name: CategoryName.new!("テストカテゴリ"),
          description: "テスト用のカテゴリ",
          created_at: DateTime.utc_now()
        })
      ]

      # イベントを保存
      assert {:ok, 1} =
               EventStore.append_events(
                 aggregate_id,
                 "CategoryAggregate",
                 events,
                 0
               )

      # イベントを取得
      assert {:ok, stored_events} = EventStore.get_events(aggregate_id)
      assert length(stored_events) == 1

      [event] = stored_events
      assert %CategoryCreated{} = event
      assert event.id.value == category_id.value
      assert event.name.value == "テストカテゴリ"
    end

    test "複数イベントの保存" do
      aggregate_id = EntityId.generate().value
      category_id = EntityId.generate()

      # 複数のイベント
      events = [
        CategoryCreated.new(%{
          id: category_id,
          name: CategoryName.new!("テストカテゴリ"),
          description: "初期作成",
          created_at: DateTime.utc_now()
        }),
        CategoryUpdated.new(%{
          id: category_id,
          name: CategoryName.new!("更新されたカテゴリ"),
          description: "更新されました",
          updated_at: DateTime.utc_now()
        })
      ]

      # イベントを保存
      assert {:ok, 2} =
               EventStore.append_events(
                 aggregate_id,
                 "CategoryAggregate",
                 events,
                 0
               )

      # イベントを取得
      assert {:ok, stored_events} = EventStore.get_events(aggregate_id)
      assert length(stored_events) == 2

      # イベントタイプの確認
      [created_event, updated_event] = stored_events
      assert %CategoryCreated{} = created_event
      assert %CategoryUpdated{} = updated_event
    end

    test "楽観的ロックの検証" do
      aggregate_id = EntityId.generate().value
      category_id = EntityId.generate()

      # 最初のイベント
      events1 = [
        CategoryCreated.new(%{
          id: category_id,
          name: CategoryName.new!("初期カテゴリ"),
          description: "初期状態",
          created_at: DateTime.utc_now()
        })
      ]

      # 保存成功
      assert {:ok, 1} =
               EventStore.append_events(
                 aggregate_id,
                 "CategoryAggregate",
                 events1,
                 0
               )

      # 同じバージョンで保存しようとすると失敗
      events2 = [
        CategoryUpdated.new(%{
          id: category_id,
          name: CategoryName.new!("更新カテゴリ"),
          description: "更新されました",
          updated_at: DateTime.utc_now()
        })
      ]

      result = EventStore.append_events(
                 aggregate_id,
                 "CategoryAggregate",
                 events2,
                 # 期待されるバージョンが間違っている
                 0
               )
               
      assert {:error, %Shared.Infrastructure.EventStore.VersionConflictError{
                aggregate_id: ^aggregate_id,
                expected_version: 0,
                actual_version: 1
              }} = result

      # 正しいバージョンで保存
      assert {:ok, 2} =
               EventStore.append_events(
                 aggregate_id,
                 "CategoryAggregate",
                 events2,
                 # 正しいバージョン
                 1
               )
    end
  end
end
