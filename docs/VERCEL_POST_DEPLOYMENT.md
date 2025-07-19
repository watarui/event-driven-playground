# Vercel デプロイ後の設定

## デプロイ情報

- **Vercel URL**: 
  - https://elixir-cqrs.vercel.app (推奨)
  - https://elixir-cqrs-watarui.vercel.app
  - https://elixir-cqrs-72z915vjs-watarui.vercel.app
- **デプロイ日時**: 2025年1月16日

## Firebase 承認済みドメインの設定

Firebase Authentication が Vercel のドメインで動作するように、以下の手順で承認済みドメインを追加してください：

1. [Firebase Console](https://console.firebase.google.com) にアクセス
2. プロジェクト `elixir-cqrs-es` を選択
3. **Authentication** → **Settings** → **Authorized domains** タブに移動
4. **Add domain** をクリック
5. 以下のドメインを追加：
   - `elixir-cqrs.vercel.app`
   - `elixir-cqrs-watarui.vercel.app`
   - `*.vercel.app` （オプション：今後のプレビューデプロイ用）

## 動作確認

### 1. 基本的なアクセス確認

```bash
# ホームページにアクセス
open https://elixir-cqrs.vercel.app
```

### 2. GraphQL エンドポイントの確認

フロントエンドは Client Service の GraphQL エンドポイントにプロキシ経由でアクセスします：

```bash
# GraphQL スキーマの確認
curl -X POST https://elixir-cqrs.vercel.app/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ __schema { queryType { name } } }"}'
```

### 3. WebSocket 接続の確認

ブラウザの開発者ツールで以下を確認：
- Network タブで WebSocket 接続を確認
- `wss://client-service-prod-581148615576.asia-northeast1.run.app/socket/websocket` への接続

### 4. Firebase Authentication の確認

1. ログインページ（/login）にアクセス
2. Google ログインボタンをクリック
3. 正常にログインできることを確認

## トラブルシューティング

### CORS エラーが発生する場合

Client Service の CORS 設定を確認する必要があります。現在は `allow-unauthenticated` で公開されているため、基本的には問題ないはずです。

### WebSocket 接続エラー

1. Client Service が起動していることを確認：
   ```bash
   curl https://client-service-prod-581148615576.asia-northeast1.run.app/health
   ```

2. ブラウザのコンソールでエラーメッセージを確認

### Firebase 認証エラー

1. Firebase Console で承認済みドメインが正しく設定されているか確認
2. Google 認証プロバイダが有効になっているか確認
3. ブラウザのコンソールでエラーメッセージを確認

## 次のステップ

1. カスタムドメインの設定（必要に応じて）
2. プロダクション用の最適化
3. モニタリングとアラートの設定
4. CI/CD パイプラインの構築

## 関連ドキュメント

- [DEPLOYMENT_STATUS_20250116.md](./DEPLOYMENT_STATUS_20250116.md) - バックエンドサービスのデプロイ状況
- [VERCEL_DEPLOYMENT_GUIDE.md](./VERCEL_DEPLOYMENT_GUIDE.md) - Vercel デプロイメントガイド
- [frontend/README.md](../frontend/README.md) - フロントエンドの詳細情報