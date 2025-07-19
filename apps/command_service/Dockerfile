# Command Service 専用 Dockerfile

# ビルドステージ
FROM elixir:1.18.1-otp-27-alpine AS builder

# ビルドに必要なパッケージをインストール
RUN apk add --no-cache \
    build-base \
    git \
    python3 \
    nodejs \
    npm

# 作業ディレクトリを設定
WORKDIR /app

# hex と rebar をインストール
RUN mix local.hex --force && \
    mix local.rebar --force

# 環境変数を設定
ENV MIX_ENV=prod

# 全体の依存関係ファイルをコピー
COPY mix.exs mix.lock ./
COPY apps/shared/mix.exs ./apps/shared/
COPY apps/client_service/mix.exs ./apps/client_service/
COPY apps/command_service/mix.exs ./apps/command_service/
COPY apps/query_service/mix.exs ./apps/query_service/

# 依存関係をインストール
RUN mix deps.get --only $MIX_ENV && \
    mix deps.compile

# アプリケーションコードをコピー
COPY config config
COPY apps apps

# アプリケーションをコンパイル
RUN mix compile

# Command Service のリリースを生成
RUN mix release command_service

# ランタイムステージ
FROM alpine:3.19

# ランタイムに必要なパッケージをインストール
RUN apk add --no-cache \
    openssl \
    ncurses-libs \
    libstdc++ \
    libgcc \
    ca-certificates \
    curl

# アプリケーション用のユーザーを作成
RUN addgroup -g 1000 -S elixir && \
    adduser -u 1000 -S elixir -G elixir

# 作業ディレクトリを設定
WORKDIR /app

# ビルドステージからリリースをコピー
COPY --from=builder --chown=elixir:elixir /app/_build/prod/rel/command_service ./

# ユーザーを切り替え
USER elixir

# Cloud Run 用の環境変数
# PORT は Cloud Run が自動的に設定するため、ここでは設定しない
ENV GOOGLE_APPLICATION_CREDENTIALS=/app/gcp-credentials.json

# ヘルスチェックポートを公開（Cloud Run は PORT 環境変数で動的に設定）
EXPOSE 8080

# ヘルスチェック
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:${PORT:-8080}/health || exit 1

# アプリケーションを起動
CMD ["/app/bin/command_service", "start"]