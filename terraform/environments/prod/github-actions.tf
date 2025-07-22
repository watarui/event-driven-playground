# GitHub Actions 用のサービスアカウント設定
# Workload Identity Federation を使用している場合の設定

# GitHub Actions サービスアカウントに必要な権限を付与
# Service Account Token Creator ロール - Workload Identity Federation で必要
resource "google_project_iam_member" "github_actions_token_creator" {
  count   = var.github_actions_service_account != "" ? 1 : 0
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${var.github_actions_service_account}"
  
  depends_on = [google_service_account.github_actions_sa]
}

# Cloud Build Editor ロール
resource "google_project_iam_member" "github_actions_cloudbuild_editor" {
  count   = var.github_actions_service_account != "" ? 1 : 0
  project = var.project_id
  role    = "roles/cloudbuild.builds.editor"
  member  = "serviceAccount:${var.github_actions_service_account}"
}

# Cloud Build Builder ロール - Cloud Build の実行に必要
resource "google_project_iam_member" "github_actions_cloudbuild_builder" {
  count   = var.github_actions_service_account != "" ? 1 : 0
  project = var.project_id
  role    = "roles/cloudbuild.builds.builder"
  member  = "serviceAccount:${var.github_actions_service_account}"
}

# Artifact Registry Writer ロール
resource "google_project_iam_member" "github_actions_artifactregistry_writer" {
  count   = var.github_actions_service_account != "" ? 1 : 0
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${var.github_actions_service_account}"
}

# Cloud Run Developer ロール
resource "google_project_iam_member" "github_actions_run_developer" {
  count   = var.github_actions_service_account != "" ? 1 : 0
  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${var.github_actions_service_account}"
}

# Service Account User ロール - 他のサービスアカウントになりすます場合に必要
resource "google_project_iam_member" "github_actions_sa_user" {
  count   = var.github_actions_service_account != "" ? 1 : 0
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${var.github_actions_service_account}"
}

# Logs Viewer ロール - ログの読み取りに必要
resource "google_project_iam_member" "github_actions_logs_viewer" {
  count   = var.github_actions_service_account != "" ? 1 : 0
  project = var.project_id
  role    = "roles/logging.viewer"
  member  = "serviceAccount:${var.github_actions_service_account}"
}

# Storage Object Viewer ロール - Cloud Build バケットの読み取りに必要
resource "google_project_iam_member" "github_actions_storage_object_viewer" {
  count   = var.github_actions_service_account != "" ? 1 : 0
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${var.github_actions_service_account}"
}

# Service Usage Consumer ロール - サービスの使用権限
resource "google_project_iam_member" "github_actions_service_usage_consumer" {
  count   = var.github_actions_service_account != "" ? 1 : 0
  project = var.project_id
  role    = "roles/serviceusage.serviceUsageConsumer"
  member  = "serviceAccount:${var.github_actions_service_account}"
}

# Workload Identity Federation の設定
# GitHub Actions がサービスアカウントになりすますことを許可
resource "google_service_account_iam_member" "github_actions_wif" {
  count              = var.github_actions_service_account != "" ? 1 : 0
  service_account_id = "projects/${var.project_id}/serviceAccounts/${var.github_actions_service_account}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${data.google_project.project.number}/locations/global/workloadIdentityPools/github/attribute.repository/watarui/event-driven-playground"
  
  depends_on = [google_service_account.github_actions_sa]
}

# プロジェクト情報の取得
data "google_project" "project" {
  project_id = var.project_id
}

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