output "firebase_config" {
  description = "Firebase configuration for frontend"
  value = {
    api_key     = var.firebase_config.api_key
    auth_domain = var.firebase_config.auth_domain
    project_id  = var.firebase_config.project_id
  }
  sensitive = true
}

output "frontend_env_local" {
  description = "frontend/.env.local の設定内容"
  value = <<-EOT
    # frontend/.env.local に以下を設定してください:
    
    NEXT_PUBLIC_GRAPHQL_ENDPOINT=http://localhost:4000/graphql
    NEXT_PUBLIC_WS_ENDPOINT=ws://localhost:4000/socket/websocket
    NEXT_PUBLIC_FIREBASE_API_KEY=${var.firebase_config.api_key}
    NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=${var.firebase_config.auth_domain}
    NEXT_PUBLIC_FIREBASE_PROJECT_ID=${var.firebase_config.project_id}
    
    # Firebase Admin SDK (管理者権限設定用)
    FIREBASE_PROJECT_ID=${var.firebase_config.project_id}
    # 以下は Firebase Console から取得
    # FIREBASE_CLIENT_EMAIL=your-service-account-email
    # FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\\nyour-private-key\\n-----END PRIVATE KEY-----"
  EOT
  sensitive = true
}

output "next_steps" {
  description = "次のステップ"
  value = <<-EOT
    ローカル開発環境の Firebase 認証設定が完了しました！
    
    次のステップ:
    1. 上記の frontend_env_local の内容を frontend/.env.local に保存
    
    2. Firebase Admin SDK の秘密鍵を取得（管理者権限が必要な場合）
       Firebase Console > プロジェクト設定 > サービスアカウント > 新しい秘密鍵の生成
    
    3. ローカルでアプリケーションを起動
       - バックエンド: mix phx.server
       - フロントエンド: cd frontend && npm run dev
  EOT
}