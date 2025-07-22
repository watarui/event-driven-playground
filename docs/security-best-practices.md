# セキュリティベストプラクティス

このドキュメントでは、本アプリケーションをエンタープライズ環境で運用する際の推奨セキュリティ設定について説明します。

## 現在の設定（デモ・ポートフォリオ用）

現在、このアプリケーションはポートフォリオ・学習用として公開されているため、以下の設定になっています：

- **アクセス制御**: `allUsers` によるパブリックアクセス
- **認証**: Firebase Authentication（クライアント側での実装）
- **最小インスタンス数**: 0（コスト削減のため）

## エンタープライズ環境での推奠設定

### 1. IAM によるアクセス制御

```hcl
# terraform/modules/cloud-run/main.tf の修正例

# 現在の設定（デモ用）
resource "google_cloud_run_v2_service_iam_member" "health_check_access" {
  # ...
  member = "allUsers"  # パブリックアクセス
}

# エンタープライズ向け推奨設定
resource "google_cloud_run_v2_service_iam_member" "authenticated_users" {
  for_each = toset(var.service_names)
  
  project  = var.project_id
  location = var.region
  name     = each.value
  role     = "roles/run.invoker"
  
  # 組織内のユーザーのみアクセス可能
  member = "domain:your-company.com"
}

# サービス間通信用の設定
resource "google_cloud_run_v2_service_iam_member" "service_to_service" {
  for_each = var.service_accounts
  
  project  = var.project_id
  location = var.region
  name     = each.key
  role     = "roles/run.invoker"
  
  # サービスアカウントによるアクセス
  member = "serviceAccount:${each.value}"
}
```

### 2. API Gateway の導入

パスベースのアクセス制御を実現するため、API Gateway の導入を推奨します：

```yaml
# api-gateway-config.yaml
swagger: '2.0'
info:
  title: Event-Driven CQRS API
  version: 1.0.0
paths:
  /health:
    get:
      operationId: health
      x-google-backend:
        address: https://client-service-xxxxx.run.app
      security: []  # ヘルスチェックは認証不要
  
  /api/**:
    get:
      operationId: api
      x-google-backend:
        address: https://client-service-xxxxx.run.app
      security:
        - firebase: []  # Firebase 認証必須

securityDefinitions:
  firebase:
    authorizationUrl: ""
    flow: "implicit"
    type: "oauth2"
    x-google-issuer: "https://securetoken.google.com/${FIREBASE_PROJECT_ID}"
    x-google-jwks_uri: "https://www.googleapis.com/service_accounts/v1/metadata/x509/securetoken@system.gserviceaccount.com"
```

### 3. Identity-Aware Proxy (IAP) の利用

より高度な認証・認可が必要な場合：

```hcl
resource "google_compute_backend_service" "default" {
  name = "cqrs-backend"
  
  iap {
    oauth2_client_id     = google_iap_client.project_client.client_id
    oauth2_client_secret = google_iap_client.project_client.secret
  }
}

resource "google_iap_web_backend_service_iam_policy" "policy" {
  project = var.project_id
  
  policy_data = jsonencode({
    bindings = [{
      role = "roles/iap.httpsResourceAccessor"
      members = [
        "group:developers@your-company.com",
        "user:admin@your-company.com"
      ]
    }]
  })
}
```

### 4. ネットワークセキュリティ

```hcl
# VPC コネクタの設定
resource "google_vpc_access_connector" "connector" {
  name          = "cqrs-connector"
  ip_cidr_range = "10.8.0.0/28"
  network       = google_compute_network.vpc.name
  region        = var.region
}

# Cloud Run サービスの VPC 接続
resource "google_cloud_run_v2_service" "service" {
  # ...
  template {
    vpc_access {
      connector = google_vpc_access_connector.connector.id
      egress    = "PRIVATE_RANGES_ONLY"
    }
  }
}
```

### 5. シークレット管理

```hcl
# Secret Manager の利用
resource "google_secret_manager_secret" "api_key" {
  secret_id = "api-key"
  
  replication {
    automatic = true
  }
}

# Cloud Run での利用
resource "google_cloud_run_v2_service" "service" {
  template {
    containers {
      env {
        name = "API_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.api_key.secret_id
            version = "latest"
          }
        }
      }
    }
  }
}
```

## セキュリティチェックリスト

- [ ] 最小権限の原則に基づいた IAM ロールの設定
- [ ] サービスアカウントの適切な管理
- [ ] API エンドポイントの認証・認可
- [ ] シークレットの Secret Manager への移行
- [ ] VPC によるネットワーク分離
- [ ] Cloud Armor による DDoS 対策
- [ ] 監査ログの有効化
- [ ] 定期的なセキュリティスキャン

## 参考リンク

- [Cloud Run セキュリティベストプラクティス](https://cloud.google.com/run/docs/securing)
- [IAM ベストプラクティス](https://cloud.google.com/iam/docs/using-iam-securely)
- [API Gateway ドキュメント](https://cloud.google.com/api-gateway/docs)
- [Identity-Aware Proxy](https://cloud.google.com/iap/docs)