# Event Driven Playground

CQRS と Event Sourcing パターンを実装した、Elixir/Phoenix ベースのマイクロサービスアーキテクチャのサンプルプロジェクトです。

## デモサイト

- **フロントエンド**: https://event-driven-playground.vercel.app/
- **GraphQL API**: https://client-service-\*.run.app/graphql

## 概要

このプロジェクトは、以下の技術とパターンを使用して構築されています：

- **CQRS (Command Query Responsibility Segregation)**: コマンドとクエリを分離
- **Event Sourcing**: イベントをデータの信頼できる唯一の情報源として使用
- **マイクロサービス**: Command Service、Query Service、Client Service (GraphQL API) の 3 つのサービス
- **イベント駆動アーキテクチャ**: Google Cloud Pub/Sub を使用したサービス間通信
- **Saga パターン**: 分散トランザクションの管理

## 技術スタック

### バックエンド

- **言語**: Elixir
- **フレームワーク**: Phoenix Framework
- **GraphQL**: Absinthe
- **データベース**: Google Firestore
- **メッセージング**: Google Cloud Pub/Sub
- **認証**: Firebase Authentication

### フロントエンド

- **フレームワーク**: Next.js (TypeScript)
- **UI ライブラリ**: Tailwind CSS, shadcn/ui
- **状態管理**: React Hooks
- **GraphQL クライアント**: Apollo Client

### インフラストラクチャ

- **バックエンドホスティング**: Google Cloud Run
- **フロントエンドホスティング**: Vercel
- **CI/CD**: GitHub Actions
- **IaC**: Terraform

## クイックスタート

### 前提条件

- Elixir 1.18+ と Erlang/OTP 28
- Node.js 20+ と bun
- Docker と Docker Compose
- Google Cloud SDK (本番デプロイの場合)

### ローカル環境のセットアップ

```bash
# リポジトリのクローン
git clone https://github.com/your-org/event-driven-playground.git
cd event-driven-playground

# 依存関係のインストールと全サービス起動（フロントエンド含む）
make start

# バックエンドのみ起動する場合
make backend
```

アプリケーションは以下の URL でアクセスできます：

- GraphQL API: http://localhost:4000/graphql
- GraphiQL (開発用 UI): http://localhost:4000/graphiql
- フロントエンド: http://localhost:3000

## プロジェクト構造

```
.
├── apps/                    # Elixir アプリケーション
│   ├── client_service/     # GraphQL API (Phoenix)
│   │   └── infrastructure/# Remote Command/Query Bus
│   ├── command_service/    # コマンド処理サービス
│   ├── query_service/      # クエリ処理サービス
│   │   └── infrastructure/# Projection Manager
│   └── shared/             # 共通ライブラリ
│       └── infrastructure/
│           └── saga/      # Saga Executor
├── frontend/               # Next.js フロントエンド
├── terraform/              # インフラストラクチャ定義
├── build/                  # ビルド設定（Docker, Cloud Build）
├── scripts/                # 開発用スクリプト
└── docs/                   # ドキュメント
```

## 主な機能

- **商品管理**: カテゴリ別の商品登録・検索
- **在庫管理**: リアルタイムな在庫追跡
- **注文処理**: 注文の作成とステータス管理
- **イベント履歴**: すべての変更履歴を追跡可能
- **分散トランザクション**: Saga パターンによる複数サービス間のトランザクション管理
- **システムモニタリング**: ヘルスチェックとトポロジー可視化

## ドキュメント

- [アーキテクチャ](ARCHITECTURE.md) - システム設計と技術的な詳細
- [開発ガイド](DEVELOPMENT.md) - ローカル開発環境の詳細なセットアップ
- [デプロイガイド](DEPLOYMENT.md) - GCP と Vercel へのデプロイ手順
- [API リファレンス](api-reference.md) - GraphQL API の仕様

## 開発コマンド

```bash
# サービスの起動・停止
make start              # 全サービスを起動（フロントエンド含む）
make backend            # バックエンドのみ起動
make stop               # すべてのサービスを停止

# 開発用コマンド
make test               # テストを実行
make logs               # ログを表示
make reset              # データベースをリセット
make seed               # サンプルデータを投入

# その他
make help               # 利用可能なコマンドを表示
```

## CI/CD

- **GitHub Actions**: `main` ブランチへのプッシュで自動デプロイ
- **Cloud Build**: Docker イメージのビルド
- **ヘルスチェック**: デプロイ前の自動検証
