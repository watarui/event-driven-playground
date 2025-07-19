# リファクタリングプラン

## 優先度: 高

### 1. 設定管理の改善

#### 現状の問題
- 各サービスで重複した設定
- 環境変数の管理が分散
- ハードコードされた値が存在

#### 改善案
```elixir
# apps/shared/lib/shared/config.ex
defmodule Shared.Config do
  def database_url(service) do
    System.get_env("#{String.upcase(service)}_DATABASE_URL") ||
      System.get_env("DATABASE_URL")
  end

  def ssl_opts do
    [
      verify: :verify_none,
      cacerts: :public_key.cacerts_get()
    ]
  end

  def pubsub_config do
    [
      project_id: System.get_env("GOOGLE_CLOUD_PROJECT"),
      emulator_host: System.get_env("PUBSUB_EMULATOR_HOST")
    ]
  end
end
```

### 2. スキーマプレフィックスの統一管理

#### 現状の問題
- 各 Ecto スキーマに手動で `@schema_prefix` を追加
- SQL クエリで手動でプレフィックスを指定

#### 改善案
```elixir
# apps/shared/lib/shared/schema_helpers.ex
defmodule Shared.SchemaHelpers do
  defmacro event_store_schema do
    quote do
      @schema_prefix "event_store"
    end
  end

  defmacro command_schema do
    quote do
      @schema_prefix "command"
    end
  end

  defmacro query_schema do
    quote do
      @schema_prefix "query"
    end
  end
end

# 使用例
defmodule Shared.Infrastructure.EventStore.Schema.Event do
  use Ecto.Schema
  import Shared.SchemaHelpers

  event_store_schema()
  
  schema "events" do
    # ...
  end
end
```

### 3. エラーハンドリングの統一

#### 現状の問題
- 各リゾルバーで同じようなエラーハンドリング
- タイムアウト処理が重複

#### 改善案
```elixir
# apps/shared/lib/shared/graphql/error_helpers.ex
defmodule Shared.GraphQL.ErrorHelpers do
  require Logger

  def handle_query_result(result, error_context) do
    case result do
      {:ok, data} ->
        {:ok, data}
      
      {:error, :timeout} ->
        Logger.error("#{error_context}: timeout")
        {:ok, []}
      
      {:error, reason} ->
        Logger.error("#{error_context}: #{inspect(reason)}")
        {:ok, []}
    end
  end
end
```

## 優先度: 中

### 4. 環境固有の設定を外部化

#### 改善案
```yaml
# config/environments/production.yml
database:
  pool_size: 10
  ssl: true
  ssl_opts:
    verify: verify_none

pubsub:
  max_demand: 100
  min_demand: 50

phoenix:
  host: "0.0.0.0"
  check_origin: false
```

### 5. ヘルスチェックの改善

#### 改善案
```elixir
# apps/shared/lib/shared/health/health_check_router.ex
defmodule Shared.Health.HealthCheckRouter do
  use Plug.Router

  plug :match
  plug :dispatch

  get "/" do
    send_json(conn, 200, %{status: "ok", timestamp: DateTime.utc_now()})
  end

  get "/ready" do
    # データベース接続チェックなど
    case check_readiness() do
      :ok -> send_json(conn, 200, %{ready: true})
      {:error, reason} -> send_json(conn, 503, %{ready: false, reason: reason})
    end
  end

  get "/live" do
    send_json(conn, 200, %{alive: true})
  end
end
```

### 6. Docker イメージの最適化

#### 改善案
```dockerfile
# ベースイメージを共通化
FROM hexpm/elixir:1.17.3-erlang-27.2-alpine-3.21.0 AS base

# 共通の依存関係をインストール
RUN apk add --no-cache \
  build-base \
  git \
  curl \
  nodejs \
  npm

# ビルドステージを最適化
FROM base AS deps
WORKDIR /app
COPY mix.exs mix.lock ./
COPY apps/*/mix.exs ./apps/
RUN mix deps.get --only prod
RUN mix deps.compile

FROM deps AS build
COPY . .
RUN mix compile
RUN mix release

# 最小限のランタイムイメージ
FROM alpine:3.21.0 AS runtime
RUN apk add --no-cache \
  libstdc++ \
  openssl \
  ncurses-libs
COPY --from=build /app/_build/prod/rel/${SERVICE_NAME} /app
CMD ["/app/bin/${SERVICE_NAME}", "start"]
```

## 優先度: 低

### 7. CI/CD パイプラインの改善

- キャッシュの活用
- 並列ビルド
- 段階的デプロイ

### 8. 監視とログの改善

- OpenTelemetry の導入
- 構造化ログ
- メトリクス収集

## 実装順序

1. **Phase 1** (1週間)
   - 設定管理の改善
   - スキーマプレフィックスの統一管理
   - エラーハンドリングの統一

2. **Phase 2** (1週間)
   - 環境固有の設定を外部化
   - ヘルスチェックの改善
   - Docker イメージの最適化

3. **Phase 3** (2週間)
   - CI/CD パイプラインの改善
   - 監視とログの改善