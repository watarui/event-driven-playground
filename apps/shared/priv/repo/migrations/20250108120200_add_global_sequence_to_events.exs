defmodule Shared.Repo.Migrations.AddGlobalSequenceToEvents do
  use Ecto.Migration

  def up do
    # グローバルシーケンス番号用のシーケンスを作成
    execute "CREATE SEQUENCE event_store.events_global_sequence_seq"
    
    alter table(:events, prefix: "event_store") do
      add :global_sequence, :bigint
    end
    
    # 既存のイベントにシーケンス番号を割り当て
    execute """
    UPDATE event_store.events 
    SET global_sequence = nextval('event_store.events_global_sequence_seq') 
    WHERE global_sequence IS NULL
    """
    
    # global_sequence を NOT NULL に変更
    alter table(:events, prefix: "event_store") do
      modify :global_sequence, :bigint, null: false
    end
    
    # グローバルシーケンスでのユニーク制約
    create unique_index(:events, [:global_sequence], prefix: "event_store")
    
    # トリガー関数を作成して自動的にシーケンス番号を設定
    execute """
    CREATE OR REPLACE FUNCTION set_event_global_sequence()
    RETURNS TRIGGER AS $$
    BEGIN
      IF NEW.global_sequence IS NULL THEN
        NEW.global_sequence := nextval('event_store.events_global_sequence_seq');
      END IF;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """
    
    # トリガーを作成
    execute """
    CREATE TRIGGER events_set_global_sequence
    BEFORE INSERT ON event_store.events
    FOR EACH ROW
    EXECUTE FUNCTION set_event_global_sequence();
    """
  end

  def down do
    # トリガーを削除
    execute "DROP TRIGGER IF EXISTS events_set_global_sequence ON event_store.events"
    
    # トリガー関数を削除
    execute "DROP FUNCTION IF EXISTS set_event_global_sequence()"
    
    # インデックスを削除
    drop unique_index(:events, [:global_sequence], prefix: "event_store")
    
    # カラムを削除
    alter table(:events, prefix: "event_store") do
      remove :global_sequence
    end
    
    # シーケンスを削除
    execute "DROP SEQUENCE IF EXISTS event_store.events_global_sequence_seq"
  end
end