# GraphQL API 認証・通信問題の調査記録

## 問題の概要

本番環境（Cloud Run）で GraphQL API を使用した際に、以下の問題が発生：

1. **初期問題**: 管理者権限があるにも関わらず「権限が不足しています: admin 権限が必要です」エラー
2. **現在の問題**: 「この操作には認証が必要です」エラー（以前とは異なるエラー）
3. **根本問題**: サービス間通信がタイムアウトする（Client Service → Command Service）

## 実施した対策と結果

### 1. JWT ロール認証の修正 ✅
**ファイル**: `apps/client_service/lib/client_service/auth/firebase_auth.ex`

```elixir
# JWT トークンから role を取得、なければ email から決定
jwt_role = claims["role"]
determined_role = if jwt_role && jwt_role != "" do
  String.to_atom(jwt_role)
else
  Shared.Auth.Permissions.determine_role(email)
end
```

**結果**: 認証は正常に動作するようになったが、サービス間通信の問題は解決せず

### 2. Google Cloud Pub/Sub アダプターの修正

#### 2.1 EventBus アダプター選択ロジックの修正 ✅
**ファイル**: `apps/shared/lib/shared/infrastructure/event_bus.ex`

```elixir
defp get_adapter do
  cond do
    System.get_env("MIX_ENV") == "prod" ->
      Logger.info("EventBus: Using GoogleCloudAdapter (MIX_ENV is prod)")
      Shared.Infrastructure.PubSub.GoogleCloudAdapter
    # ...
  end
end
```

**結果**: GOOGLE_CLOUD_PROJECT 環境変数は設定されているが、アダプターのログが出力されない

#### 2.2 トピック名のサニタイズ ✅
**ファイル**: `apps/shared/lib/shared/infrastructure/pubsub/google_cloud_adapter.ex`

```elixir
defp format_topic_name(topic, project_id) do
  environment = System.get_env("MIX_ENV", "dev")
  # トピック名に @ が含まれる場合は - に置換（PubSub の制限）
  sanitized_topic = topic |> to_string() |> String.replace("@", "-at-")
  "projects/#{project_id}/topics/#{sanitized_topic}-#{environment}"
end
```

**理由**: `command_responses_client_service@localhost` のような @ を含むトピック名は PubSub で使用不可

#### 2.3 必要なトピックの手動作成 ✅
```bash
gcloud pubsub topics create commands-prod
gcloud pubsub topics create command_responses_client_service-at-localhost-prod
gcloud pubsub topics create query_responses_client_service-at-localhost-prod
```

### 3. ログフォーマットの問題対応

#### 3.1 JSON フォーマットを一時的にテキスト形式に変更 ✅
**ファイル**: `config/prod.exs`

```elixir
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :trace_id, :span_id, :aggregate_id, :event_type, :service]
```

**結果**: FORMATTER CRASH エラーが解消され、正常なログが出力されるように

### 4. GoogleCloudAdapter の初期化問題

#### 4.1 child_spec のタイプ修正 ✅
```elixir
%{
  id: name,
  start: {__MODULE__, :start_link, [opts]},
  type: :worker  # :supervisor から変更
}
```

#### 4.2 Phoenix.PubSub.Adapter の必須メソッド実装 ✅
```elixir
@impl Phoenix.PubSub.Adapter
def subscribe(adapter_name, pid, topic, opts \\ []) do
  GenServer.call(adapter_name, {:subscribe, pid, topic})
end

@impl Phoenix.PubSub.Adapter
def unsubscribe(adapter_name, pid, topic) do
  GenServer.call(adapter_name, {:unsubscribe, pid, topic})
end
```

#### 4.3 Connection.new() のエラーハンドリング追加 ✅
```elixir
connection = try do
  conn = Connection.new()
  Logger.info("GoogleCloudAdapter: Connection created successfully")
  conn
rescue
  e ->
    Logger.error("GoogleCloudAdapter: Failed to create connection: #{inspect(e)}")
    raise e
end
```

**結果**: Signal 10 (SIGUSR1) エラーが発生し続けている

## 現在の状況

### エラーの変化
- **以前**: 「権限が不足しています: admin 権限が必要です」
- **現在**: 「この操作には認証が必要です」

これは進歩している可能性があります。認証自体は通っているが、何らかの理由で認証情報が失われている可能性があります。

### 根本的な問題
1. GoogleCloudAdapter の初期化時に Signal 10 エラーが発生
2. EventBus が正しく起動していない
3. サービス間の PubSub 通信が機能していない

## 今後の対応事項

### 1. 短期的な対応
1. **認証情報の伝播を確認** ✅
   - GraphQL のコンテキストに認証情報が正しく設定されているか → AbsintheContextPlug を作成して修正
   - Middleware での認証チェックのロジックを確認 → 完了
   - Firebase プロジェクト ID の設定を修正 → runtime.exs で GOOGLE_CLOUD_PROJECT をフォールバックとして使用

2. **GoogleCloudAdapter の問題を回避**
   - 一時的に HTTP 通信に切り替える → 実装中
   - または、すべてのサービスを単一のサービスに統合する → マイクロサービスアーキテクチャを維持するため却下

### 2. 中長期的な対応
1. **Goth ライブラリの設定確認**
   - Cloud Run のサービスアカウント認証が正しく動作しているか
   - 必要な IAM ロールが付与されているか

2. **Google Cloud Pub/Sub の代替案検討**
   - Cloud Tasks を使用した非同期通信
   - Firestore を使用したポーリングベースの通信
   - gRPC を使用した直接通信

3. **ログとモニタリングの改善**
   - Axiom への JSON ログ出力の修正
   - Cloud Logging との統合改善
   - 分散トレーシングの実装

### 3. 推奨される次のステップ

1. **認証問題の調査**
   ```bash
   # 認証ミドルウェアのログを詳細に確認
   gcloud logging read 'resource.type="cloud_run_revision" AND 
     resource.labels.service_name="client-service" AND 
     textPayload:"Authorization"' --limit=50
   ```

2. **一時的な回避策の実装**
   - すべてのサービスを client-service に統合
   - または、HTTP エンドポイントを追加してサービス間通信を実現

3. **IAM 権限の確認**
   ```bash
   # サービスアカウントの権限を確認
   gcloud projects get-iam-policy event-driven-playground-prod \
     --flatten="bindings[].members" \
     --filter="bindings.members:serviceAccount:*@*"
   ```

## 学んだこと

1. **Cloud Run での PubSub 使用は複雑**
   - サービスアカウント認証の設定が必要
   - Signal エラーはライブラリの初期化問題を示唆

2. **ログフォーマットの重要性**
   - JSON フォーマットは構造化ログには良いが、デバッグ時は問題になることがある
   - 開発/デバッグ時は標準的なテキストフォーマットが有用

3. **段階的な問題解決**
   - 認証の問題を解決しても、通信の問題が残る
   - 複数の問題が絡み合っている場合は、一つずつ切り分けることが重要

## 参考リンク

- [Cloud Run での認証](https://cloud.google.com/run/docs/authenticating/overview)
- [Google Cloud Pub/Sub Elixir クライアント](https://github.com/googleapis/elixir-google-api/tree/master/clients/pub_sub)
- [Phoenix.PubSub アダプターの実装](https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.Adapter.html)