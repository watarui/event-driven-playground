# Firebase Authentication for Phoenix

このディレクトリには、Phoenix Framework で Firebase Authentication を使用するためのカスタム実装が含まれています。

## アーキテクチャ

Guardian を使用せず、シンプルなプラグベースの実装を採用しています。

### コンポーネント

1. **FirebaseAuth** - Firebase JWT トークンの検証ロジック
2. **FirebasePlug** - Authorization ヘッダーからトークンを取得し検証
3. **ContextPlug** - GraphQL コンテキストに認証情報を追加
4. **EnsureAuthenticatedPlug** - 認証が必要なエンドポイントの保護
5. **EnsureAdminPlug** - 管理者権限が必要なエンドポイントの保護

## 使用方法

### Router での設定

```elixir
pipeline :authenticated_api do
  plug(:accepts, ["json"])
  plug(ClientService.Auth.FirebasePlug)
  plug(ClientService.Auth.ContextPlug)
  plug(ClientServiceWeb.Plugs.DataloaderPlug)
end

# 認証が必要なエンドポイント
scope "/api" do
  pipe_through :authenticated_api
  
  # ここに認証が必要なルートを追加
end

# 管理者権限が必要なエンドポイント
scope "/admin" do
  pipe_through [:authenticated_api]
  plug ClientService.Auth.EnsureAdminPlug
  
  # ここに管理者用のルートを追加
end
```

### GraphQL での使用

GraphQL リゾルバーでは、コンテキストから認証情報にアクセスできます：

```elixir
def resolve_user_profile(_, _, %{context: %{current_user: user}}) do
  {:ok, user}
end

def resolve_user_profile(_, _, _) do
  {:error, "Not authenticated"}
end
```

## トークンの形式

クライアントは以下の形式で Authorization ヘッダーを送信する必要があります：

```
Authorization: Bearer <firebase-id-token>
```

## エラーレスポンス

- **401 Unauthorized** - 認証されていない場合
- **403 Forbidden** - 権限が不足している場合

## 廃止されたファイル

以下のファイルは Guardian ベースの実装で、新しい実装では使用されません：

- `guardian.ex` - Guardian の実装モジュール
- `pipeline.ex` - Guardian パイプライン
- `auth_plug.ex` - Guardian と連携する認証プラグ
- `error_handler.ex` - Guardian のエラーハンドラー