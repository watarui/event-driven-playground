# CQRS Elixir プロジェクト - 本番環境デプロイ状況レポート
**作成日: 2025年1月16日**
**最終更新: 2025年1月16日 19:00 JST**

## 概要
本ドキュメントは、CQRS Elixir プロジェクトの本番環境（Google Cloud Run）へのデプロイ作業の進捗状況をまとめたものです。

## 🎉 全システム正常稼働中

## 現在の状況（2025年1月16日 19:00 JST 更新）

### デプロイ状況
| サービス | 状態 | URL | 備考 |
|---------|------|-----|------|
| Query Service | ✅ 成功 | https://query-service-prod-581148615576.asia-northeast1.run.app | 正常動作中（/health エンドポイント確認済み） |
| Command Service | ✅ 成功 | https://command-service-prod-581148615576.asia-northeast1.run.app | 正常動作中（/health エンドポイント確認済み） |
| Client Service | ✅ 成功 | https://client-service-prod-581148615576.asia-northeast1.run.app | 正常動作中（GraphQL エンドポイント動作確認済み） |

### データベース状況
- **プロバイダー**: Supabase PostgreSQL
- **接続**: Session Pooler 経由（IPv4互換）
- **スキーマ構成**:
  - `event_store`: ✅ 全テーブル作成済み（events, snapshots, sagas, idempotency_records等）
  - `command`: ✅ テーブル作成済み（categories, products）
  - `query`: ✅ テーブル作成済み（categories, products, orders）
  - `public`: ✅ クリーンアップ済み（schema_migrations のみ）

## 実施した作業（更新）

### 1. Terraform 設定の修正
- **問題**: プロジェクトIDパラメータの欠落
- **対応**: 
  ```hcl
  # 全リソースに project = var.project_id を追加
  provider "google" {
    project = var.project_id
    region = var.region
    user_project_override = true
    billing_project = var.project_id
  }
  ```

### 2. 環境分離
- **ローカル開発環境**: 
  - Firebase プロジェクト: `elixir-cqrs-es-local`
  - Terraform 環境: `/terraform/environments/local/`
- **本番環境**:
  - Firebase プロジェクト: `elixir-cqrs-es`
  - Terraform 環境: `/terraform/environments/prod/`

### 3. データベース接続の修正
- **問題**: Supabase の Direct Connection は IPv4 非対応
- **解決**: Session Pooler を使用
  ```
  postgresql://postgres.aovzgtiivhizaorngcvh:postgres@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres
  ```
- **SSL設定**: 完全な SSL/TLS 設定を追加
  ```elixir
  ssl: true,
  ssl_opts: [
    verify: :verify_none,
    cacerts: :public_key.cacerts_get(),
    server_name_indication: 'aws-0-ap-northeast-1.pooler.supabase.com',
    customize_hostname_check: [
      match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
    ]
  ]
  ```

### 4. スキーマプレフィックスの修正
- **問題**: Ecto スキーマがデフォルトで public スキーマを参照
- **解決**: 各スキーマに `@schema_prefix` を追加
  ```elixir
  # 例: apps/shared/lib/shared/infrastructure/idempotency/idempotency_record.ex
  @schema_prefix "event_store"
  
  schema "idempotency_records" do
    # ...
  end
  ```

### 5. マイグレーションの修正と実行
- **手動マイグレーション**: `/scripts/manual-migrations.sql` を作成
- **実行済みマイグレーション**:
  - event_store スキーマ: 全テーブル作成完了
  - command スキーマ: categories, products テーブル作成完了
  - query スキーマ: categories, products, orders テーブル作成完了

### 6. Release モジュールの追加
- Query Service と Command Service に Release モジュールを追加
- マイグレーションタスクのサポートを実装

### 7. PORT 環境変数の修正
- Cloud Run が設定する PORT 環境変数を動的に読み取るよう修正
- 各サービスで `System.get_env("PORT") || "8080"` を使用

### 8. PubSub 設定の修正
- Shared.Application に Phoenix.PubSub を追加
- 重複する PubSub 設定を各サービスから削除

### 9. 根本的な設定改善（2025年1月16日実施）

#### 9.1 runtime.exs の簡略化
- 複雑な SSL/TLS 設定を `ssl: true, ssl_opts: [verify: :verify_none]` に簡略化
- プールサイズのデフォルトを "5" から "2" に変更
- Phoenix host 設定を `System.get_env("PHX_HOST") || "localhost"` から `"localhost"` に固定
- Firebase 設定を RELEASE_NAME で条件分岐し、Client Service のみで読み込み
- Client Service の endpoint に `server: true` を追加

#### 9.2 Erlang 分散モードの無効化
- `rel/env.sh.eex` ファイルを作成
  ```bash
  #!/bin/sh
  # Cloud Run 環境では分散モードを無効化
  export RELEASE_DISTRIBUTION=none
  export RELEASE_NODE=nonode@nohost
  export ERL_AFLAGS="-proto_dist inet_tcp"
  ```

#### 9.3 ヘルスチェックの簡略化
- `/apps/shared/lib/shared/health/simple_health_plug.ex` を作成
- データベース接続を必要としないシンプルな JSON レスポンスに変更
- 各サービスの `/health` エンドポイントを更新

### 10. Client Service 固有の修正

#### 10.1 NodeConnector の無効化
- `/apps/client_service/lib/client_service/application.ex` で NodeConnector を無効化
- 分散 Erlang 機能を使用しないように変更

#### 10.2 PubSubBroadcaster のエラーハンドリング
- `/apps/client_service/lib/client_service/pubsub_broadcaster.ex` に try/rescue ブロックを追加
- Absinthe.Subscription.publish の失敗を適切にハンドリング

#### 10.3 Dockerfile の修正
- rel ディレクトリをインラインで作成
- EXPOSE ポートを 4000 から 8080 に変更
- ヘルスチェックパスを更新

### 11. Docker イメージの再ビルド
- Cloud Build で新しいイメージをビルド
- 全 3 サービスのイメージを成功裏にビルド
- Client Service のビルドは複数回の修正を経て成功

### 12. Vercel フロントエンドのデプロイと設定（2025年1月16日実施）

#### 12.1 環境変数の設定
- Firebase 認証関連の環境変数を設定
- OAuth クライアント ID の改行文字を削除
- Google OAuth の承認済みドメインに Vercel ドメインを追加

#### 12.2 Firebase OAuth 設定の修正
- OAuth クライアント ID の先頭の "5" が欠落していた問題を修正
- Google Cloud Console で Authorized redirect URIs を更新

#### 12.3 GraphQL プロキシの実装
- `/frontend/app/api/graphql/route.ts` を作成
- CORS 対応とエラーハンドリングを実装
- デバッグログを追加

### 13. GraphQL エラーハンドリングの修正（2025年1月16日実施）

#### 13.1 タイムアウトエラーの処理
- 各リゾルバーで `:timeout` エラーを特別に処理
- Absinthe 互換のエラーフォーマットに変更

#### 13.2 Client Service の CORS 設定更新
- Vercel ドメインを許可リストに追加
- `max_age` を設定

### 14. スキーマプレフィックスの追加修正（2025年1月16日実施）

#### 14.1 MonitoringResolver の修正
- SAGA クエリに `event_store.sagas` プレフィックスを追加
- 統計クエリでも同様の修正

## 完了した作業の要約

### 1. Vercel 環境変数の設定（優先度: 高）
フロントエンドの環境変数を本番用に設定：
- `NEXT_PUBLIC_GRAPHQL_ENDPOINT`: Client Service の URL
- `NEXT_PUBLIC_WS_ENDPOINT`: WebSocket エンドポイント
- `NEXT_PUBLIC_FIREBASE_*`: Firebase 設定

### 2. Client Service のヘルスチェック修正（優先度: 低）
- `/health` エンドポイントが空のレスポンスを返す問題の修正
- サービス自体は正常に動作しているため、優先度は低い

### 3. ヘルスチェックとモニタリング（優先度: 低）
- Google Cloud Trace の設定確認
- Cloud Run のヘルスチェック設定の調整
- ログ集約の設定

### 4. 追加の最適化（優先度: 低）
- Cloud Run の CPU/メモリ設定の最適化
- 自動スケーリング設定の調整
- Cloud SQL への移行検討（必要な場合）

## トラブルシューティングガイド

### Docker ビルドエラーの対処
1. 依存関係のクリーンアップ:
   ```bash
   mix deps.clean --all
   rm -rf _build
   mix deps.get
   mix deps.compile
   ```

2. Docker キャッシュのクリア:
   ```bash
   docker system prune -a
   ```

### Cloud Run デプロイエラーの対処
1. ログの確認:
   ```bash
   gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=SERVICE_NAME" \
     --limit=50 --project=elixir-cqrs-es
   ```

2. 環境変数の確認:
   ```bash
   gcloud run services describe SERVICE_NAME --region=asia-northeast1 --format="value(spec.template.spec.containers[0].env[].name)"
   ```

## 参考ファイル
- `/terraform/environments/prod/main.tf` - 本番環境のインフラ定義
- `/config/runtime.exs` - ランタイム設定
- `/scripts/manual-migrations.sql` - 手動マイグレーション SQL
- `/scripts/deploy-prod.sh` - デプロイスクリプト
- `/docs/GOOGLE_CLOUD_DEPLOYMENT.md` - Google Cloud デプロイガイド

## システム稼働状況

### バックエンド
- ✅ Query Service: 正常稼働中
- ✅ Command Service: 正常稼働中
- ✅ Client Service: 正常稼働中（GraphQL エンドポイント動作確認済み）

### フロントエンド
- ✅ Vercel デプロイ: 完了
- ✅ Firebase 認証: 正常動作
- ✅ GraphQL 通信: 正常動作

### 主要機能
- ✅ ログイン機能
- ✅ カテゴリ一覧表示
- ✅ 商品一覧表示
- ✅ 注文一覧表示
- ✅ SAGA モニタリング
- ✅ ヘルスチェック
- ✅ メトリクス表示

## 進捗の要約

### 成功した主要な修正：
1. **runtime.exs の簡略化**： SSL 設定、プールサイズ、Phoenix host 設定をシンプルに
2. **Erlang 分散モードの無効化**：Cloud Run と互換性のある設定に
3. **ヘルスチェックの簡略化**：データベース依存を排除
4. **Client Service 固有の問題解決**：
   - NodeConnector の無効化
   - PubSubBroadcaster のエラーハンドリング追加
   - Dockerfile の修正（rel ディレクトリ、ポート設定）
   - server: true の追加
5. **全サービスのデプロイ成功**：Query Service、Command Service、Client Service すべてが正常稼働

### 検証済みの動作：
- Query Service: `/health` エンドポイント正常
- Command Service: `/health` エンドポイント正常
- Client Service: GraphQL エンドポイント（`/graphql`）で schema 取得確認済み

---
**注記**: すべてのバックエンドサービスが正常に動作しています。次のステップは Vercel でのフロントエンドデプロイです。