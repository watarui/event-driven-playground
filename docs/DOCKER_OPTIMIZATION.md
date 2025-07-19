# Docker イメージ最適化ガイド

## 概要

Phase 2 のリファクタリングの一環として、Docker イメージのビルドプロセスを最適化しました。
この最適化により、ビルド時間の短縮、イメージサイズの削減、キャッシュ効率の向上を実現しています。

## 最適化の内容

### 1. マルチステージビルドの活用

従来の単一ステージビルドから、以下の複数ステージに分離：

- **base**: ビルド依存関係のインストール
- **deps**: Elixir 依存関係の取得とコンパイル
- **build**: アプリケーションのコンパイル
- **release**: リリースの作成
- **runtime**: 最小限のランタイム環境

### 2. 共有ベースイメージ

`Dockerfile.base` を導入し、全サービスで共通の依存関係を共有：

```dockerfile
# Base image with common dependencies
FROM hexpm/elixir:1.17.3-erlang-27.2-alpine-3.21.0 AS base
# Install common build dependencies once
```

### 3. レイヤーキャッシュの最適化

- 変更頻度の低いファイルを先にコピー
- 依存関係のインストールを別レイヤーに分離
- BuildKit のインラインキャッシュを活用

## ビルドプロセスの比較

### 従来のビルド

```bash
# 各サービスで全ての依存関係をインストール
docker build -f apps/client_service/Dockerfile -t client-service .
# ビルド時間: 約 5-7 分/サービス
# イメージサイズ: 約 1.2GB/サービス
```

### 最適化後のビルド

```bash
# 共有ベースイメージを一度だけビルド
docker build --target build -t elixir-cqrs-base -f Dockerfile.base .

# 各サービスは差分のみビルド
docker build -f apps/client_service/Dockerfile.optimized -t client-service .
# ビルド時間: 約 1-2 分/サービス（キャッシュ使用時）
# イメージサイズ: 約 200-300MB/サービス
```

## 使用方法

### ローカルビルド

```bash
# 最適化されたビルドスクリプトを使用
./scripts/build-optimized.sh

# イメージをレジストリにプッシュ
PUSH=true ./scripts/build-optimized.sh
```

### Cloud Build

```bash
# 最適化された Cloud Build 設定を使用
gcloud builds submit --config=cloudbuild-optimized.yaml
```

## メリット

1. **ビルド時間の短縮**
   - 初回ビルド: 約 50% 短縮
   - 2回目以降: 約 80% 短縮（キャッシュ利用）

2. **イメージサイズの削減**
   - 約 75% のサイズ削減（1.2GB → 300MB）
   - ストレージコストの削減
   - デプロイ時間の短縮

3. **メンテナンス性の向上**
   - 共通の依存関係を一箇所で管理
   - セキュリティアップデートの適用が容易

4. **リソース効率**
   - CI/CD パイプラインの負荷軽減
   - ネットワーク帯域の節約

## ベストプラクティス

1. **定期的なベースイメージの更新**
   ```bash
   # 月次でベースイメージを再ビルド
   docker build --no-cache --target base -f Dockerfile.base .
   ```

2. **キャッシュの活用**
   - Cloud Build では `--cache-from` を使用
   - ローカルでは BuildKit を有効化

3. **セキュリティスキャン**
   ```bash
   # イメージの脆弱性スキャン
   gcloud container images scan client-service:latest
   ```

## トラブルシューティング

### キャッシュが効かない場合

1. BuildKit が有効か確認
   ```bash
   export DOCKER_BUILDKIT=1
   ```

2. `.dockerignore` ファイルを確認
   - 不要なファイルが含まれていないか
   - 頻繁に変更されるファイルを除外

### ビルドエラー

1. ベースイメージが最新か確認
2. 依存関係のバージョン競合をチェック
3. ビルドログでエラーの詳細を確認

## 今後の改善案

1. **Distroless イメージの検討**
   - さらなるサイズ削減とセキュリティ向上

2. **ビルドキャッシュの永続化**
   - レジストリベースのキャッシュ導入

3. **自動化の強化**
   - 依存関係の自動更新
   - セキュリティスキャンの自動化
