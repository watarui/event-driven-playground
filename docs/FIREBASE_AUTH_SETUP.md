# Firebase Authentication セットアップガイド

## OAuth2 リダイレクト URI エラーの解決方法

エラーメッセージ:
```
FirebaseError: Firebase: Error getting access token from google.com, OAuth2 redirect uri is: https://elixir-cqrs-es-local.firebaseapp.com/__/auth/handler
```

このエラーは、Firebase プロジェクトの設定と環境変数の不一致が原因です。

## 解決手順

### 1. Firebase Console での設定確認

1. [Firebase Console](https://console.firebase.google.com/) にアクセス
2. プロジェクトを選択
3. 左メニューから「Authentication」を選択
4. 「Sign-in method」タブを開く
5. 「Google」プロバイダーを有効化し、設定を開く

### 2. 承認済みドメインの確認

1. Authentication → Settings → Authorized domains
2. 以下のドメインが登録されているか確認：
   - `localhost`
   - あなたの本番ドメイン（例: `your-app.vercel.app`）

### 3. Google Cloud Console での OAuth 2.0 設定

1. [Google Cloud Console](https://console.cloud.google.com/) にアクセス
2. Firebase プロジェクトに対応する GCP プロジェクトを選択
3. 「APIとサービス」→「認証情報」を開く
4. OAuth 2.0 クライアント ID を確認
5. 「承認済みのリダイレクト URI」に以下を追加：
   - `http://localhost:3000`
   - `https://your-firebase-project.firebaseapp.com/__/auth/handler`
   - あなたの本番環境の URL

### 4. 環境変数の確認

`.env.local` ファイルで以下の値が正しいか確認：

```env
NEXT_PUBLIC_FIREBASE_API_KEY=your-api-key
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=your-project.firebaseapp.com  # 重要: この値が正しいか確認
NEXT_PUBLIC_FIREBASE_PROJECT_ID=your-project-id
```

特に `NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN` が Firebase プロジェクトと一致していることを確認してください。

### 5. Firebase プロジェクト ID の確認

エラーメッセージの `elixir-cqrs-es-local` があなたの Firebase プロジェクト ID と一致しているか確認してください。

## トラブルシューティング

### よくある問題

1. **プロジェクト ID の不一致**
   - `.env.local` の `NEXT_PUBLIC_FIREBASE_PROJECT_ID` が正しいか確認
   - Firebase Console でプロジェクト ID を再確認

2. **Auth Domain の設定ミス**
   - `NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN` は通常 `{project-id}.firebaseapp.com` の形式
   - カスタムドメインを使用している場合は、それを指定

3. **OAuth クライアントの設定漏れ**
   - Google Cloud Console で OAuth 2.0 クライアント ID の設定を確認
   - リダイレクト URI が正しく登録されているか確認

### デバッグ方法

1. ブラウザの開発者ツールでネットワークタブを確認
2. Firebase Auth のリクエストで使用されている URL を確認
3. 環境変数が正しく読み込まれているか確認：
   ```javascript
   console.log('Auth Domain:', process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN)
   ```

## 参考リンク

- [Firebase Authentication ドキュメント](https://firebase.google.com/docs/auth/web/google-signin)
- [Firebase Console](https://console.firebase.google.com/)
- [Google Cloud Console](https://console.cloud.google.com/)