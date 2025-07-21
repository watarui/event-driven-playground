# マルチサービス用の統合 Dockerfile
# このファイルはルートディレクトリから全サービスをビルドする場合に使用

# ビルドステージ
FROM elixir:1.18.4-otp-28-alpine AS builder

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

# 各サービスのリリースを生成
RUN mix release client_service && \
    mix release command_service && \
    mix release query_service

# ランタイムステージ - Elixir イメージをベースに使用
FROM elixir:1.18.4-otp-28-alpine AS runtime-base

# ランタイムに必要な最小限のパッケージをインストール
RUN apk add --no-cache \
    ca-certificates

# アプリケーション用のユーザーを作成
RUN addgroup -g 1000 -S elixir && \
    adduser -u 1000 -S elixir -G elixir

# 作業ディレクトリを設定
WORKDIR /app

# Client Service
FROM runtime-base AS client_service
COPY --from=builder --chown=elixir:elixir /app/_build/prod/rel/client_service ./
USER elixir
CMD ["/app/bin/client_service", "start"]

# Command Service
FROM runtime-base AS command_service
COPY --from=builder --chown=elixir:elixir /app/_build/prod/rel/command_service ./
USER elixir
CMD ["/app/bin/command_service", "start"]

# Query Service
FROM runtime-base AS query_service
COPY --from=builder --chown=elixir:elixir /app/_build/prod/rel/query_service ./
USER elixir
CMD ["/app/bin/query_service", "start"]
