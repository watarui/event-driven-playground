# 管理者権限の設定方法

このドキュメントでは、CQRS/ES システムで管理者権限を設定する方法を説明します。

## 概要

本システムは Firebase Authentication のカスタムクレームを使用してロールベースのアクセス制御を実装しています。

- **Admin**: すべてのクエリとミューテーションを実行可能
- **Viewer**: クエリのみ実行可能（デフォルト）

## 初回管理者の設定

### 方法1: Web UI から設定（推奨）

1. アプリケーションにログイン
2. GraphQL Explorer ページ (`/graphiql`) にアクセス
3. Viewer ロールの警告が表示されている場合、「管理者として設定」ボタンをクリック
4. ページをリロードすると管理者権限が反映されます

### 方法2: Firebase Console から手動設定

1. [Firebase Console](https://console.firebase.google.com) にアクセス
2. プロジェクトを選択
3. 「Authentication」→「Users」タブを開く
4. 対象ユーザーの UID をコピー
5. Cloud Shell または Firebase Admin SDK を使用して以下を実行：

```javascript
// Node.js スクリプト例
const admin = require('firebase-admin');
admin.initializeApp();

await admin.auth().setCustomUserClaims('USER_UID_HERE', { role: 'admin' });
```

## 他のユーザーに管理者権限を付与

管理者権限を持つユーザーは、API を通じて他のユーザーのロールを変更できます：

```bash
# 管理者権限を付与
curl -X POST http://localhost:4001/api/admin/set-role \
  -H "Authorization: Bearer YOUR_FIREBASE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "uid": "TARGET_USER_UID",
    "role": "admin"
  }'
```

## トラブルシューティング

### 管理者権限が反映されない場合

1. ブラウザをリロード
2. 一度ログアウトして再ログイン
3. Firebase トークンが最新であることを確認

### エラーが発生する場合

- Firebase Admin SDK の環境変数が正しく設定されているか確認
- `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY` が必要です

## セキュリティに関する注意

- 初回管理者設定は、システムに管理者が一人もいない場合のみ可能です
- 一度管理者が設定されると、新しい管理者の追加は既存の管理者のみが実行できます
- Firebase のカスタムクレームは JWT トークンに含まれるため、変更後はトークンの更新が必要です