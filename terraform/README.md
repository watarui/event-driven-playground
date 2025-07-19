# Terraform Infrastructure

このディレクトリには、環境ごとの Terraform 構成が含まれています。

## ディレクトリ構造

```
terraform/
├── modules/                    # 再利用可能なモジュール
│   ├── cloud-run/             # Cloud Run サービス
│   ├── firebase/              # Firebase Authentication
│   ├── monitoring/            # Cloud Monitoring
│   └── pubsub/               # Pub/Sub トピック・サブスクリプション
├── environments/              # 環境別構成
│   ├── local/                # ローカル開発環境（Firebase認証のみ）
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars.example
│   └── dev/                  # 開発環境（フルクラウドリソース）
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars.example
└── versions.tf               # 共通のバージョン制約

```

## 環境の使い分け

### ローカル開発環境 (`environments/local/`)
- **用途**: ローカルでの開発・デバッグ
- **リソース**: Firebase Authentication のみ
- **コスト**: 最小限（Firebase の無料枠内）
- **使用タイミング**: 日常的な開発作業

```bash
cd environments/local
terraform init
terraform apply
```

### 開発環境 (`environments/dev/`)
- **用途**: クラウド上での統合テスト
- **リソース**: 
  - Cloud Run（マイクロサービス）
  - Pub/Sub（メッセージング）
  - Secret Manager（機密情報管理）
  - Artifact Registry（Docker イメージ）
  - Cloud Monitoring（監視）
- **コスト**: 使用量に応じて課金
- **使用タイミング**: CI/CD、統合テスト、デモ

```bash
cd environments/dev
terraform init
terraform apply -var-file=terraform.tfvars
```

## セットアップ手順

### 1. Google Cloud プロジェクトの準備
```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

### 2. OAuth クライアントの作成
1. [Google Cloud Console](https://console.cloud.google.com) にアクセス
2. APIとサービス → 認証情報 → OAuth クライアント ID を作成
3. 承認済みのオリジンとリダイレクトURIを設定

### 3. 環境に応じた設定
- **ローカル開発**: `environments/local/terraform.tfvars` を作成
- **開発環境**: `environments/dev/terraform.tfvars` を作成

## 注意事項

- `terraform.tfvars` ファイルには機密情報が含まれるため、Git にコミットしないでください
- 本番環境へのデプロイ前に、必ず開発環境でテストしてください
- 不要なリソースは `terraform destroy` で削除してコストを節約しましょう