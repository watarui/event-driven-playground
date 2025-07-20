# Firebase 承認済みドメイン設定ガイド

## 問題
Vercel デプロイ後、Firebase Authentication で以下のエラーが発生：
```
The requested action is invalid.
```

## 解決方法

### 1. Firebase Console で承認済みドメインを追加

1. [Firebase Console](https://console.firebase.google.com/) にアクセス
2. プロジェクト `event-driven-playground-prod` を選択
3. 左メニューから **Authentication** → **Settings** → **Authorized domains** を開く
4. 以下のドメインを追加:
   - `event-driven-playground.vercel.app`
   - `*.vercel.app` (開発用プレビューデプロイ用)

### 2. Google Cloud Console で OAuth リダイレクト URI を追加

1. [Google Cloud Console](https://console.cloud.google.com/) にアクセス
2. プロジェクト `event-driven-playground-prod` を選択
3. **APIs & Services** → **Credentials** を開く
4. OAuth 2.0 Client ID をクリック
5. **Authorized redirect URIs** に以下を追加:
   ```
   https://event-driven-playground-prod.firebaseapp.com/__/auth/handler
   https://event-driven-playground.vercel.app/__/auth/handler
   ```

### 3. 設定の確認

Firebase の設定が正しいことを確認：
- Project ID: `event-driven-playground-prod`
- Auth Domain: `event-driven-playground-prod.firebaseapp.com`

## 現在の設定

### 環境変数 (.env.production)
```
NEXT_PUBLIC_FIREBASE_API_KEY=AIzaSyD3UGpfArhs8y5Y6Vy8xMupV7qEBgtetxE
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=event-driven-playground-prod.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=event-driven-playground-prod
```

### Cloud Run サービス URL
- Client Service: `https://client-service-yfmozh2e7a-an.a.run.app`
- Command Service: `https://command-service-yfmozh2e7a-an.a.run.app`
- Query Service: `https://query-service-yfmozh2e7a-an.a.run.app`

## 注意事項

- Firebase Console での設定変更は即座に反映されます
- Google Cloud Console での OAuth 設定変更は数分かかる場合があります
- Vercel のプレビューデプロイを使用する場合は、動的に生成される URL も承認済みドメインに追加する必要があります