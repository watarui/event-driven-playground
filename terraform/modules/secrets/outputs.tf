# 環境変数名とシークレット ID のマッピング
output "env_var_secrets" {
  description = "Map of environment variable names to secret IDs for Cloud Run"
  value = {
    # Firebase API キー
    FIREBASE_API_KEY = google_secret_manager_secret.secrets["firebase_api_key"].id
    
    # アプリケーションシークレット
    SECRET_KEY_BASE = google_secret_manager_secret.secrets["secret_key_base"].id
  }
}

# 後方互換性のための出力（将来的に削除予定）
output "secret_ids" {
  description = "Map of secret names to their IDs (deprecated)"
  value = {
    for k, v in google_secret_manager_secret.secrets : k => v.id
  }
}

output "secret_names" {
  description = "Map of secret names to their actual secret names in GCP"
  value = {
    for k, v in google_secret_manager_secret.secrets : k => v.secret_id
  }
}