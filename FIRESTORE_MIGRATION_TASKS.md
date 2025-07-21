# Firestore 移行作業ガイド

## ユーザー作業リスト

### 1. Google Cloud プロジェクトの設定（本番環境用）
- [ ] Google Cloud Console で Firestore API を有効化
  ```bash
  gcloud services enable firestore.googleapis.com --project=event-driven-playground-prod
  ```
- [ ] Firestore データベースの作成（ネイティブモード）
  - リージョン: `asia-northeast1` (東京)
  - モード: **Native mode** を選択（Datastore mode ではない）

### 2. Firebase Tools のインストール（ローカル開発用）
- [ ] Node.js がインストールされていることを確認
- [ ] Firebase Tools をグローバルインストール
  ```bash
  npm install -g firebase-tools
  ```
- [ ] Firebase にログイン
  ```bash
  firebase login
  ```

### 3. 環境変数の設定
- [ ] `.env.local` ファイルに以下を追加（ローカル開発用）
  ```env
  # Firestore Emulator
  FIRESTORE_EMULATOR_HOST_EVENT_STORE=localhost:8080
  FIRESTORE_EMULATOR_HOST_COMMAND=localhost:8081
  FIRESTORE_EMULATOR_HOST_QUERY=localhost:8082
  ```

### 4. サービスアカウントキーの準備（オプション）
- [ ] 開発環境でエミュレータを使わない場合のみ
  - Google Cloud Console からサービスアカウントキーをダウンロード
  - `credentials/` フォルダに配置（.gitignore 済み）

## AI が実行中の作業

### 現在進行中
1. 依存関係の追加（mix.exs）
2. Docker Compose の設定作成
3. リポジトリ層の抽象化

### 今後の作業予定
1. 各サービスの Firestore 実装
2. テストの更新
3. 本番環境の Terraform 設定

## 決定事項メモ
- 開発環境: 複数の Firestore Emulator インスタンス（完全分離）
- 本番環境: 単一 Firestore + 名前空間分離（コスト最適化）
- PostgreSQL から Firestore への移行
- CQRS パターンは維持