# Firestore 移行作業ガイド

## ユーザー作業リスト

### 1. Google Cloud プロジェクトの設定（本番環境用）✅ 完了
- [x] Google Cloud Console で Firestore データベースを作成
  - リージョン: `asia-northeast1` (東京)
  - モード: **Native mode** を選択
  - データベース ID: `(default)`

### 2. Firebase Tools のインストール（ローカル開発用）✅ 完了
- [x] Firebase Tools をインストール
- [x] Firebase にログイン

### 3. 開発環境のセットアップ
- [ ] 依存関係のインストール
  ```bash
  mix deps.get
  ```
- [ ] Docker ネットワークの作成（初回のみ）
  ```bash
  docker network create event-driven-network
  ```
- [ ] Firestore Emulator の起動
  ```bash
  docker-compose -f docker-compose.firestore.yml up -d
  ```

### 4. 動作確認
- [ ] ローカルで Firestore モードで起動
  ```bash
  # config/dev.exs の database_adapter を :firestore に設定済み
  mix phx.server
  ```
- [ ] ブラウザで http://localhost:4000 にアクセス
- [ ] 基本的な操作（商品登録、注文作成など）をテスト

### 5. 本番環境へのデプロイ
- [ ] Terraform で本番環境を更新
  ```bash
  cd terraform/environments/prod
  terraform plan
  terraform apply
  ```
- [ ] GitHub Actions でデプロイ（main ブランチにマージ後自動実行）

## AI が実行中の作業

### 完了した作業
1. ✅ 依存関係の追加（mix.exs）
2. ✅ Docker Compose の設定作成
3. ✅ リポジトリ層の抽象化
4. ✅ Event Store の Firestore 実装

### 現在進行中
1. Command Service の Firestore 実装
2. Query Service の Firestore 実装

### 今後の作業予定
1. 既存のリポジトリ実装を Firestore に切り替え
2. テストの更新
3. 本番環境の Terraform 設定
4. CI/CD パイプラインの更新

## 決定事項メモ
- 開発環境: 複数の Firestore Emulator インスタンス（完全分離）
- 本番環境: 単一 Firestore + 名前空間分離（コスト最適化）
- PostgreSQL から Firestore への移行
- CQRS パターンは維持