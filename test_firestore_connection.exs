#!/usr/bin/env elixir

# Firestore 接続テストスクリプト

# Mix アプリケーションを開始
Mix.start()
Mix.env(:dev)

# プロジェクトのルートに移動
File.cd!("/Users/w/w/event-driven-playground")

# 依存関係を読み込む
Code.append_path("_build/dev/lib/shared/ebin")
Code.append_path("_build/dev/lib/command_service/ebin")
Code.append_path("_build/dev/lib/query_service/ebin")

# アプリケーションを起動
Application.ensure_all_started(:hackney)
Application.ensure_all_started(:jason)
Application.ensure_all_started(:tesla)
Application.ensure_all_started(:google_api_firestore)

# 環境変数を設定
System.put_env("FIRESTORE_EMULATOR_HOST", "localhost:8090")
System.put_env("FIRESTORE_PROJECT_ID", "demo-project")

# テストを実行
defmodule FirestoreConnectionTest do
  def run do
    IO.puts("=== Firestore 接続テスト開始 ===")
    
    # エミュレータクライアントを作成
    case Shared.Infrastructure.Firestore.EmulatorClient.create_client(:shared) do
      nil ->
        IO.puts("❌ エミュレータクライアントの作成に失敗しました")
        
      client ->
        IO.puts("✅ エミュレータクライアントを作成しました")
        
        # テストドキュメントを作成
        test_data = %{
          "name" => %{"stringValue" => "テスト商品"},
          "price" => %{"integerValue" => "1000"},
          "created_at" => %{"timestampValue" => DateTime.to_iso8601(DateTime.utc_now())}
        }
        
        case Shared.Infrastructure.Firestore.EmulatorClient.create_or_update_document(
          client,
          "demo-project",
          "test_collection",
          "test_doc_1",
          test_data
        ) do
          {:ok, result} ->
            IO.puts("✅ ドキュメントの作成に成功しました")
            IO.inspect(result, label: "作成結果")
            
            # ドキュメントを取得
            case Shared.Infrastructure.Firestore.EmulatorClient.get_document(
              client,
              "demo-project",
              "test_collection",
              "test_doc_1"
            ) do
              {:ok, doc} ->
                IO.puts("✅ ドキュメントの取得に成功しました")
                IO.inspect(doc, label: "取得結果")
                
              {:error, reason} ->
                IO.puts("❌ ドキュメントの取得に失敗しました: #{inspect(reason)}")
            end
            
          {:error, reason} ->
            IO.puts("❌ ドキュメントの作成に失敗しました: #{inspect(reason)}")
        end
    end
    
    IO.puts("\n=== Firestore 接続テスト完了 ===")
  end
end

# テストを実行
FirestoreConnectionTest.run()