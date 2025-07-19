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
COPY apps/shared/mix.exs ./apps/shared/

# 依存関係をインストール
RUN mix deps.get --only $MIX_ENV && \
    mix deps.compile

# アプリケーションコードをコピー
COPY config config
COPY apps/shared apps/shared

# アプリケーションをコンパイル
RUN mix compile

# リリースを生成
RUN mix release shared

# ランタイムステージ
FROM alpine:3.19

# ランタイムに必要なパッケージをインストール
RUN apk add --no-cache \
    openssl \
    ncurses-libs \
    libstdc++ \
    libgcc

# アプリケーション用のユーザーを作成
RUN addgroup -g 1000 -S elixir && \
    adduser -u 1000 -S elixir -G elixir

# 作業ディレクトリを設定
WORKDIR /app

# リリースをコピー
COPY --from=builder --chown=elixir:elixir /app/_build/prod/rel/shared ./

# ユーザーを切り替え
USER elixir

# ヘルスチェック
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD /app/bin/shared pid || exit 1

# アプリケーションを起動
CMD ["/app/bin/shared", "start"]