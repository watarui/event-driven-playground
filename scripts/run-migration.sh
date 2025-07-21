#!/bin/bash
# マイグレーション実行用の便利スクリプト

set -e

# デフォルト値
MIGRATION_TYPE="workaround"
DRY_RUN="false"
BUILD_NEW_IMAGE="false"

# 使い方を表示
usage() {
    echo "使い方: $0 [オプション]"
    echo ""
    echo "オプション:"
    echo "  -t, --type TYPE        マイグレーションタイプ (workaround|ecto) [デフォルト: workaround]"
    echo "  -d, --dry-run          Dry run モード（変更なし）"
    echo "  -b, --build            新しいイメージをビルドしてから実行"
    echo "  -h, --help             このヘルプを表示"
    echo ""
    echo "例:"
    echo "  $0                     # デフォルト設定で実行（workaround）"
    echo "  $0 --dry-run           # Dry run モードで確認"
    echo "  $0 --build             # 新しいイメージをビルドして実行"
    echo "  $0 --type ecto         # Ecto マイグレーションを実行（タイムアウト注意）"
    exit 1
}

# オプション解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            MIGRATION_TYPE="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN="true"
            shift
            ;;
        -b|--build)
            BUILD_NEW_IMAGE="true"
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "エラー: 不明なオプション $1"
            usage
            ;;
    esac
done

# バリデーション
if [[ "$MIGRATION_TYPE" != "workaround" && "$MIGRATION_TYPE" != "ecto" ]]; then
    echo "エラー: マイグレーションタイプは 'workaround' または 'ecto' を指定してください"
    exit 1
fi

# 確認
echo "=========================================="
echo "マイグレーション実行設定"
echo "=========================================="
echo "タイプ: $MIGRATION_TYPE"
echo "Dry Run: $DRY_RUN"
echo "新規ビルド: $BUILD_NEW_IMAGE"
echo ""

if [[ "$DRY_RUN" == "false" ]]; then
    echo "⚠️  警告: 実際にマイグレーションを実行します"
    echo -n "続行しますか？ (yes/no): "
    read -r response
    if [[ "$response" != "yes" ]]; then
        echo "キャンセルしました"
        exit 0
    fi
fi

# GitHub CLI をチェック
if ! command -v gh &> /dev/null; then
    echo "エラー: GitHub CLI (gh) がインストールされていません"
    echo "インストール方法: https://cli.github.com/"
    exit 1
fi

# 認証チェック
if ! gh auth status &> /dev/null; then
    echo "エラー: GitHub CLI で認証されていません"
    echo "実行: gh auth login"
    exit 1
fi

# ワークフローを実行
echo ""
echo "🚀 GitHub Actions ワークフローを起動中..."

gh workflow run "Run Database Migration" \
    -f confirm="migrate" \
    -f migration_type="$MIGRATION_TYPE" \
    -f dry_run="$DRY_RUN" \
    -f build_new_image="$BUILD_NEW_IMAGE"

echo ""
echo "✅ ワークフローを起動しました"
echo ""
echo "進捗を確認するには:"
echo "  1. GitHub リポジトリの Actions タブを開く"
echo "  2. または以下のコマンドを実行:"
echo "     gh run list --workflow=\"Run Database Migration\" -L 1"
echo ""
echo "ログを確認するには:"
echo "     gh run view"