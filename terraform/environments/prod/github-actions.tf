# GitHub Actions 用のサービスアカウント設定
# 注: GitHub Actions は Workload Identity Federation を使用している可能性があります
# 正確なサービスアカウント名は GitHub Actions の WIF_SERVICE_ACCOUNT シークレットを確認してください

# 一時的な解決策として、Cloud Run サービスアカウントに Jobs の実行権限を追加
resource "google_project_iam_member" "cloud_run_sa_run_jobs" {
  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Cloud Run サービスアカウントに Jobs の管理権限を追加
resource "google_project_iam_member" "cloud_run_sa_run_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}