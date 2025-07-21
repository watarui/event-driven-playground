# Firestore セットアップガイド

## 概要

このプロジェクトは Google Cloud Firestore を使用しています。ローカル開発では Firestore エミュレータが Docker で自動的に起動します。

## ローカル開発環境

### 1. 起動方法

```bash
# Docker コンテナの起動（Firestore エミュレータ）
docker compose up -d

# 初回セットアップ
./scripts/setup.sh

# サービス起動
./scripts/start.sh
```

### 2. Firestore エミュレータ

- **URL**: http://localhost:8090
- **データの永続化**: なし（コンテナ再起動でリセット）
- **設定**: `docker-compose.yml` で定義

### 3. アーキテクチャ

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ Command Service │     │  Query Service  │     │  Event Store    │
│   (Port 4081)   │     │   (Port 4082)   │     │                 │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                         │
         └───────────────────────┴─────────────────────────┘
                                 │
                    ┌────────────┴────────────┐
                    │  Firestore Emulator    │
                    │     (Port 8090)         │
                    └─────────────────────────┘
```

## 本番環境

### 1. Google Cloud Firestore

- **リージョン**: `asia-northeast1` (東京)
- **モード**: Native mode
- **認証**: Cloud Run のサービスアカウントで自動認証

### 2. データ構造

#### Event Store
```
/events/{eventId}
  - aggregate_id: string
  - aggregate_type: string
  - event_type: string
  - event_data: map
  - event_version: number
  - occurred_at: timestamp
```

#### Command Service
```
/categories/{categoryId}
  - name: string
  - description: string
  - parent_id: string (optional)
  - created_at: timestamp
  - updated_at: timestamp

/products/{productId}
  - name: string
  - description: string
  - price: number
  - stock: number
  - category_id: string
  - created_at: timestamp
  - updated_at: timestamp
```

#### Query Service
```
/categories/{categoryId}
  - (Command Service と同じ構造)

/products/{productId}
  - (Command Service と同じ構造)

/orders/{orderId}
  - customer_name: string
  - total_amount: number
  - items: array
  - status: string
  - created_at: timestamp
```

## トラブルシューティング

### Firestore エミュレータが起動しない

```bash
# ログを確認
docker compose logs firestore

# コンテナを再起動
docker compose restart firestore
```

### データをリセットしたい

```bash
# 完全リセット（エミュレータも再起動）
./scripts/reset.sh

# または手動でエミュレータを再起動
docker compose restart firestore
```

### ポートが使用中

```bash
# ポートの使用状況を確認
make status

# 既存のプロセスを停止
./scripts/stop.sh --all
```

## 開発のヒント

1. **データの確認**: Firestore エミュレータ UI (http://localhost:8090) でデータを確認できます
2. **ログの確認**: `./scripts/logs.sh` でサービスのログを確認
3. **シードデータ**: `./scripts/seed.sh` でサンプルデータを投入

## 関連ドキュメント

- [Firestore 公式ドキュメント](https://cloud.google.com/firestore/docs)
- [Firestore エミュレータ](https://firebase.google.com/docs/emulator-suite/connect_firestore)