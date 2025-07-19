# Client Service 専用 Dockerfile for Google Cloud Run

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

# 依存関係ファイルをコピー
COPY mix.exs mix.lock ./
COPY apps/client_service/mix.exs ./apps/client_service/
COPY apps/shared/mix.exs ./apps/shared/

# 依存関係をインストール
RUN mix deps.get --only $MIX_ENV && \
    mix deps.compile

# アプリケーションコードをコピー
COPY config config
COPY apps apps

# rel/env.sh.eex ファイルが必要な場合
RUN mkdir -p rel && \
    echo '#!/bin/sh' > rel/env.sh.eex && \
    echo '# Cloud Run 環境では分散モードを無効化' >> rel/env.sh.eex && \
    echo 'export RELEASE_DISTRIBUTION=none' >> rel/env.sh.eex && \
    echo 'export RELEASE_NODE=nonode@nohost' >> rel/env.sh.eex && \
    echo 'export ERL_AFLAGS="-proto_dist inet_tcp"' >> rel/env.sh.eex

# アセットをビルド（必要な場合）
# RUN cd apps/client_service/assets && \
#     npm install && \
#     npm run deploy && \
#     cd .. && \
#     mix phx.digest

# アプリケーションをコンパイル
RUN mix compile

# リリースを生成
RUN mix release client_service

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

# リリースをコピー
COPY --from=builder --chown=elixir:elixir /app/_build/prod/rel/client_service ./

# ユーザーを切り替え
USER elixir

# Cloud Run 用の環境変数
# PORT は Cloud Run が自動的に設定するため、ここでは設定しない
ENV PHX_HOST=0.0.0.0
ENV GOOGLE_APPLICATION_CREDENTIALS=/app/gcp-credentials.json

# ポートを公開（Cloud Run は PORT 環境変数で動的に設定）
EXPOSE 8080

# ヘルスチェック
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:${PORT:-8080}/health || exit 1

# アプリケーションを起動
CMD ["/app/bin/client_service", "start"]