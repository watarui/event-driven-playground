# ==============================================================================
# Elixir CQRS プロジェクト Makefile
# ==============================================================================

# カラー定義
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
CYAN := \033[0;36m
NC := \033[0m # No Color

# デフォルトターゲット
.DEFAULT_GOAL := help

# シェル設定
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# スクリプトディレクトリ
SCRIPTS_DIR := ./scripts

# ==============================================================================
# メインコマンド
# ==============================================================================

## Docker起動 → セットアップ → バックエンド起動 → フロントエンド起動 → シード投入（DB が空の場合のみ）
.PHONY: start
start: docker-up
	@echo -e "$(GREEN)🚀 全サービスを起動します$(NC)"
	@$(SCRIPTS_DIR)/start.sh --frontend --seed

## すべてのサービスを停止
.PHONY: stop
stop:
	@echo -e "$(YELLOW)🛑 すべてのサービスを停止します$(NC)"
	@$(SCRIPTS_DIR)/stop.sh
	@echo -e "$(GREEN)✅ 停止完了$(NC)"

## 完全リセット（データ削除、ログクリーン、コンテナ削除）
.PHONY: reset
reset:
	@echo -e "$(RED)⚠️  完全リセットを実行します$(NC)"
	@$(SCRIPTS_DIR)/reset.sh
	@echo -e "$(YELLOW)🧹 ログファイルとビルド成果物をクリーンアップ$(NC)"
	@rm -rf logs/*.log
	@rm -rf _build deps
	@rm -rf frontend/.next frontend/node_modules
	@echo -e "$(GREEN)✅ リセット完了$(NC)"

## ログ表示（tail -f）
.PHONY: logs
logs:
	@$(SCRIPTS_DIR)/logs.sh

# ==============================================================================
# 個別コマンド
# ==============================================================================

## Docker コンテナのみ起動
.PHONY: docker-up
docker-up:
	@echo -e "$(BLUE)🐳 Docker コンテナを起動します$(NC)"
	@if ! docker compose ps --services --filter "status=running" | grep -q .; then \
		docker compose up -d; \
		echo -e "$(GREEN)✅ Docker コンテナ起動完了$(NC)"; \
	else \
		echo -e "$(CYAN)ℹ️  Docker コンテナは既に起動しています$(NC)"; \
	fi

## Docker コンテナ停止
.PHONY: docker-down
docker-down:
	@echo -e "$(YELLOW)🐳 Docker コンテナを停止します$(NC)"
	@docker compose down
	@echo -e "$(GREEN)✅ Docker コンテナ停止完了$(NC)"

## バックエンドのみ起動
.PHONY: backend
backend: docker-up
	@echo -e "$(BLUE)🔧 バックエンドサービスを起動します$(NC)"
	@$(SCRIPTS_DIR)/start.sh
	@echo -e "$(GREEN)✅ バックエンド起動完了$(NC)"

## フロントエンドのみ起動（Next.js の出力をそのまま表示）
.PHONY: frontend
frontend:
	@echo -e "$(BLUE)💻 フロントエンドを起動します$(NC)"
	@cd frontend && npm run dev

## シードデータ投入
.PHONY: seed
seed:
	@echo -e "$(YELLOW)📦 シードデータを投入します$(NC)"
	@$(SCRIPTS_DIR)/seed.sh
	@echo -e "$(GREEN)✅ シード投入完了$(NC)"

## 初回セットアップ
.PHONY: setup
setup:
	@echo -e "$(BLUE)🔧 初回セットアップを実行します$(NC)"
	@$(SCRIPTS_DIR)/setup.sh
	@echo -e "$(GREEN)✅ セットアップ完了$(NC)"

# ==============================================================================
# 便利なコマンド
# ==============================================================================

## ビルド成果物とログをクリーン
.PHONY: clean
clean:
	@echo -e "$(YELLOW)🧹 クリーンアップを実行します$(NC)"
	@rm -rf logs/*.log
	@rm -rf _build deps
	@rm -rf frontend/.next frontend/node_modules
	@echo -e "$(GREEN)✅ クリーンアップ完了$(NC)"

## 各サービスの状態確認
.PHONY: status
status:
	@echo -e "$(BLUE)📊 サービス状態確認$(NC)"
	@echo -e "\n$(CYAN)Docker コンテナ:$(NC)"
	@docker compose ps
	@echo -e "\n$(CYAN)Elixir ノード:$(NC)"
	@-epmd -names 2>/dev/null || echo "  EPMDが起動していません"
	@echo -e "\n$(CYAN)ポート使用状況:$(NC)"
	@-lsof -i :4000 -P -n | grep LISTEN || echo "  ポート 4000 (GraphQL): 未使用"
	@-lsof -i :4081 -P -n | grep LISTEN || echo "  ポート 4081 (Command): 未使用"
	@-lsof -i :4082 -P -n | grep LISTEN || echo "  ポート 4082 (Query): 未使用"
	@-lsof -i :3000 -P -n | grep LISTEN || echo "  ポート 3000 (Frontend): 未使用"
	@-lsof -i :8090 -P -n | grep LISTEN || echo "  ポート 8090 (Firestore): 未使用"

# ==============================================================================
# ヘルプ
# ==============================================================================

## ヘルプを表示
.PHONY: help
help:
	@echo -e "$(BLUE)Elixir CQRS プロジェクト - 利用可能なコマンド$(NC)"
	@echo ""
	@echo -e "$(GREEN)メインコマンド:$(NC)"
	@grep -E '^## ' $(MAKEFILE_LIST) | grep -A1 '^\.PHONY: ' | \
		awk 'BEGIN {FS = "(: |##)"}; !/^--/ && /^\.PHONY/ {cmd=$$2} /^## / {printf "  $(CYAN)%-15s$(NC) %s\n", cmd, $$2}'
	@echo ""
	@echo -e "$(YELLOW)使用例:$(NC)"
	@echo "  make start     # 全サービスを起動（シード投入含む）"
	@echo "  make stop      # 全サービスを停止"
	@echo "  make reset     # 完全リセット"
	@echo "  make logs      # ログを表示"
	@echo "  make status    # サービス状態を確認"