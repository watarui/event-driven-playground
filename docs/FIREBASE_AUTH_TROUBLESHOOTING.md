# Firebase Authentication トラブルシューティング

## 問題: "Illegal url for new iframe" エラー

### エラーメッセージ
```
Error: Illegal url for new iframe - https://elixir-cqrs-es.firebaseapp.com%0A/__/auth/iframe?apiKey=...
```

### 原因
環境変数に改行文字（`%0A`）が含まれていた

### 解決方法

1. **環境変数の再設定**
   - Vercel の環境変数から古い値を削除
   - `echo -n` を使用して改行なしで値を設定
   - すべての Firebase 関連の環境変数を確認・修正

2. **実行したコマンド**
   ```bash
   # 環境変数を削除して再設定（改行なし）
   echo "y" | vercel env rm NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN production
   echo -n "elixir-cqrs-es.firebaseapp.com" | vercel env add NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN production
   ```

3. **再デプロイ**
   ```bash
   vercel --prod
   ```

## Firebase Console での設定確認

### 承認済みドメインの設定

1. [Firebase Console](https://console.firebase.google.com) にアクセス
2. プロジェクト `elixir-cqrs-es` を選択
3. **Authentication** → **Settings** → **Authorized domains**
4. 以下のドメインが追加されていることを確認：
   - `elixir-cqrs.vercel.app`
   - `elixir-cqrs-watarui.vercel.app`
   - `localhost` (開発用)

### Google 認証プロバイダの設定

1. **Authentication** → **Sign-in method**
2. Google プロバイダが有効になっていることを確認
3. 設定を開いて以下を確認：
   - Web SDK configuration が正しく設定されている
   - Web client ID が自動生成されている

## デバッグ方法

### ブラウザのコンソールで確認

```javascript
// Firebase の設定が正しく読み込まれているか
console.log(window.__NEXT_DATA__.props.pageProps);

// 環境変数の値を確認（開発環境のみ）
console.log(process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN);
```

### ネットワークタブで確認

1. 開発者ツールの Network タブを開く
2. Google ログインボタンをクリック
3. Firebase Auth への リクエストを確認
4. URL に改行文字（`%0A`）が含まれていないか確認

## その他の注意点

- 環境変数を設定する際は、必ず改行が含まれないように注意
- Vercel の Web UI で環境変数を設定する場合も、値の前後に空白や改行がないか確認
- 環境変数を変更した後は必ず再デプロイが必要