# GitHub Actions 用のサービスアカウント設定
# 注: このファイルは GitHub Actions の WIF_SERVICE_ACCOUNT シークレットで
# 指定されているサービスアカウントに権限を追加します

# GitHub Actions サービスアカウントに Cloud Run Jobs の実行権限を追加
resource "google_project_iam_member" "github_actions_run_jobs" {
  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:github-actions@${var.project_id}.iam.gserviceaccount.com"
}

# GitHub Actions サービスアカウントに Cloud Run Admin 権限を追加（Jobs の作成/更新に必要）
resource "google_project_iam_member" "github_actions_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:github-actions@${var.project_id}.iam.gserviceaccount.com"
}