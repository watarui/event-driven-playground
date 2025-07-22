# GitHub Actions 専用のサービスアカウント
resource "google_service_account" "github_actions_sa" {
  project      = var.project_id
  account_id   = "github-actions"
  display_name = "GitHub Actions Service Account"
  description  = "Service account for GitHub Actions CI/CD"
}

# このサービスアカウントの email を出力
output "github_actions_service_account_email" {
  value = google_service_account.github_actions_sa.email
}