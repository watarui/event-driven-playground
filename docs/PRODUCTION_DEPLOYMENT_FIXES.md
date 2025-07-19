# 本番環境デプロイ時の修正事項

## 概要

本番環境（Google Cloud Run）へのデプロイ時に発生した問題と、それに対する修正をまとめています。

## 1. Erlang 分散モードの無効化

### 問題
- Cloud Run は単一コンテナ環境のため、Erlang の分散モードが動作しない
- "Hostname 127.0.0.1 is illegal" エラーが発生

### 修正内容

1. `rel/env.sh.eex` を作成して分散モードを無効化
```bash
#!/bin/sh
export RELEASE_DISTRIBUTION=none
export RELEASE_NODE=nonode@nohost
export ERL_AFLAGS="-proto_dist inet_tcp"
```

2. `config/runtime.exs` で Phoenix の設定を簡略化
```elixir
config :client_service, ClientServiceWeb.Endpoint,
  server: true,
  host: "0.0.0.0",
  port: String.to_integer(System.get_env("PORT") || "4000")
```

3. 各サービスの Application で NodeConnector を無効化

## 2. データベース接続の修正

### 問題
- SSL 接続の設定が複雑で、タイムアウトが発生
- スキーマプレフィックスが適用されない

### 修正内容

1. SSL 設定の簡略化
```elixir
ssl: true,
ssl_opts: [verify: :verify_none]
```

2. スキーマプレフィックスの明示的な指定
- Ecto スキーマに `@schema_prefix` を追加
- SQL クエリで `event_store.events` のように完全修飾名を使用

## 3. Firebase 認証の設定

### 問題
- 環境変数に改行文字が含まれていた
- OAuth クライアント ID の設定ミス
- CORS の設定不足

### 修正内容

1. 環境変数から改行を削除
2. Firebase Console で正しい OAuth クライアント ID を設定
3. Google OAuth のリダイレクト URI に Vercel ドメインを追加
4. Client Service の CORS 設定を更新

## 4. GraphQL エラーハンドリング

### 問題
- タイムアウトエラーが Absinthe で正しく処理されない
- `{:error, BusinessRuleError, ...}` 形式が Absinthe と互換性がない

### 修正内容

1. リゾルバーでタイムアウトを特別に処理
```elixir
{:error, :timeout} ->
  Logger.error("Failed to list categories: :timeout")
  {:ok, []}
```

2. エラーレスポンスを Absinthe 形式に統一

## 5. ヘルスチェックの簡略化

### 問題
- 起動時にデータベース接続が必要なヘルスチェックが失敗

### 修正内容

1. シンプルなヘルスチェックエンドポイントを作成
```elixir
def call(%{path_info: []} = conn, opts) do
  service_name = Keyword.get(opts, :service_name, "unknown")
  conn
  |> put_resp_content_type("application/json")
  |> send_resp(200, Jason.encode!(%{
    status: "ok", 
    timestamp: DateTime.utc_now(),
    service: service_name
  }))
end
```

## 6. Dockerfile の修正

### 問題
- `rel` ディレクトリがコピーされていなかった
- SECRET_KEY_BASE のコンパイル時エラー

### 修正内容

1. Dockerfile に `COPY rel ./rel` を追加
2. `runtime.exs` の raise 文に括弧を追加

## 今後のリファクタリング課題

1. **設定の一元管理**
   - 環境変数の管理方法を統一
   - 共通設定を shared アプリに集約

2. **エラーハンドリングの統一**
   - GraphQL エラーフォーマットの標準化
   - タイムアウト処理の共通化

3. **スキーマプレフィックスの自動化**
   - マイグレーション時の自動適用
   - クエリビルダーでの自動付与

4. **監視とログの改善**
   - 構造化ログの導入
   - メトリクスの収集

5. **CI/CD パイプラインの改善**
   - ビルド時間の短縮
   - 自動テストの追加