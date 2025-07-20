# Build ディレクトリ

このディレクトリには、プロジェクトのビルドとデプロイに関連する設定ファイルが含まれています。

## ディレクトリ構造

```
build/
├── cloudbuild/          # Cloud Build 設定ファイル
│   ├── optimized.yaml   # 本番用最適化ビルド設定
│   ├── migrate.yaml     # データベースマイグレーション用
│   └── *.yaml          # その他のビルド設定
│
├── docker/             # Dockerfile
│   ├── Dockerfile      # メインの統合 Dockerfile（全サービス用）
│   ├── Dockerfile.base # ベースイメージ
│   ├── Dockerfile.migrate # マイグレーション実行用
│   └── Dockerfile.simple  # シンプル版（開発用）
│
└── cloud-run/          # Cloud Run デプロイ設定
    ├── services.yaml   # マイクロサービスの定義
    └── jobs.yaml       # Cloud Run Jobs の定義
```

## 使用方法

### ローカルビルド

```bash
# ベースイメージのビルド
docker build -f build/docker/Dockerfile.base -t event-driven-playground-base .

# サービスのビルド（統合 Dockerfile を使用）
docker build -f build/docker/Dockerfile --target client_service -t client-service .
docker build -f build/docker/Dockerfile --target command_service -t command-service .
docker build -f build/docker/Dockerfile --target query_service -t query-service .
```

### Cloud Build

```bash
# 本番用ビルド（最適化版）
gcloud builds submit --config=build/cloudbuild/optimized.yaml

# マイグレーション実行
gcloud builds submit --config=build/cloudbuild/migrate.yaml
```

### Cloud Run デプロイ

```bash
# サービスのデプロイ設定を適用
gcloud run services replace build/cloud-run/services.yaml

# ジョブの作成/更新
gcloud run jobs replace build/cloud-run/jobs.yaml
```

## 注意事項

- すべてのパスはプロジェクトルートからの相対パスで指定されています
- CI/CD パイプライン（GitHub Actions）もこれらのパスを参照しています
- Dockerfile は統合版を使用し、各サービスは異なるターゲットステージとしてビルドされます