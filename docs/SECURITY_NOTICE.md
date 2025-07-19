# セキュリティ通知

## Terraform State ファイルについて

### 重要な警告

Terraform の state ファイル（`.tfstate`）には以下の機密情報が含まれる可能性があります：

- データベースのパスワード
- API キー
- OAuth クライアントシークレット
- サービスアカウントの認証情報
- その他の機密設定値

### 対応済み事項

1. `.gitignore` を更新して state ファイルを除外
2. 既に Git で追跡されていた state ファイルを削除

### 推奨事項

1. **ローカルの state ファイルを確認**
   ```bash
   # 機密情報が含まれていないか確認
   grep -i "secret\|password\|key" terraform/environments/*/terraform.tfstate
   ```

2. **リモートバックエンドの使用を検討**
   ```hcl
   terraform {
     backend "gcs" {
       bucket  = "your-terraform-state-bucket"
       prefix  = "terraform/state"
     }
   }
   ```

3. **state ファイルの暗号化**
   - Google Cloud Storage バックエンドを使用する場合、自動的に暗号化されます
   - ローカルの場合は、ディスク暗号化を有効にしてください

### Git 履歴のクリーンアップ

もし過去のコミットに state ファイルが含まれている場合：

```bash
# BFG Repo-Cleaner を使用（推奨）
bfg --delete-files "*.tfstate" --no-blob-protection

# または git filter-branch を使用
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch terraform/**/*.tfstate' \
  --prune-empty --tag-name-filter cat -- --all
```

**注意**: 履歴の書き換えは慎重に行ってください。チームメンバーへの通知が必要です。

### 今後の予防策

1. pre-commit フックの設定
2. CI/CD でのセキュリティスキャン
3. 定期的な機密情報の監査