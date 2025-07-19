# ELIXIR CQRS 学習プロジェクト - バランス型リファクタリング計画

## プロジェクトの再定義

### 目的
マイクロサービスアーキテクチャを維持しながら、各技術要素を学習に適したレベルで実装する：
- **マイクロサービス**: Command/Query/Client の 3 サービス構成を維持
- **認証認可**: Firebase Authentication ベースの 3 段階権限（admin/write/read）
- **監視・メトリクス**: 基本的な実装で概念を学習
- **レジリエンス**: DLQ、サーキットブレーカー、冪等性を適度に実装
- **GraphQL**: 学習用として維持
- **インフラ**: Google Cloud Run + Terraform（Kubernetes は削除）

### 現状の問題と解決方針
- **260 ファイル → 120-150 ファイル**を目標（50% 削減）
- 過剰な抽象化を削除し、直接的な実装を採用
- 重複実装を統合し、共通化できる部分は shared に集約
- 学習の妨げにならない程度の実用性を保持

## 並列実行可能なタスク一覧

### 🚀 即座に開始可能なタスク（並列実行推奨）

#### タスクグループ A: インフラストラクチャ簡素化
1. **A-1: イベントストアの簡素化** [5 ファイル削減]
   - PostgreSQL アダプターを主実装に
   - InMemory アダプターをテスト用のみに
   - スナップショット機能の簡素化

2. **A-2: Service Discovery の簡素化** [6 ファイル削減]
   - 環境変数ベースの単純な実装に変更
   - ServiceRegistry, ServiceRegistrar の削除

3. **A-3: 冪等性管理の統合** [4 ファイル削減]
   - ETS ベースのシンプルな実装に統合
   - 複雑なストレージアダプターを削除

#### タスクグループ B: 認証認可の改善
1. **B-1: 認証ミドルウェアの更新** [3 ファイル更新]
   - ドメイン全体の認証制限を解除
   - 未ログインユーザーの読み取りアクセスを許可
   - 書き込み操作のみ認証を要求

2. **B-2: GraphQL スキーマの更新** [2 ファイル更新]
   - Query は認証不要
   - Mutation は権限チェック
   - Subscription は権限に応じたフィルタリング

3. **B-3: フロントエンドの認証UI最適化** [3 ファイル更新]
   - ログイン前でも読み取りコンテンツを表示
   - 書き込み操作時のみログインを要求
   - ユーザー権限に応じたUI表示制御

#### タスクグループ C: Saga パターンの適正化
1. **C-1: Saga 実装の簡素化** [17 ファイル削減]
   - 基本的な Saga エンジンのみ保持
   - 複雑な補償トランザクション機能を削除
   - タイムアウト管理を簡素化

2. **C-2: Saga ストアの統合** [3 ファイル削減]
   - PostgreSQL ベースの単一実装に
   - アダプターパターンを削除

#### タスクグループ D: DLQ とサーキットブレーカー
1. **D-1: Dead Letter Queue の簡素化** [2 ファイル削減]
   - 基本的なエラー保存機能のみ
   - 手動リトライ機能の実装

2. **D-2: サーキットブレーカーの簡素化** [4 ファイル削減]
   - Fuse ライブラリを直接使用
   - カスタム実装を削除

#### タスクグループ E: ドキュメント・スクリプトの整理
1. **E-1: Kubernetes 関連ドキュメントの削除** [3 ファイル削除]
   - Kubernetes デプロイメントガイドを削除
   - k8s マニフェストのサンプルを削除

2. **E-2: 古い Auth0 関連ドキュメントの削除** [2 ファイル削除]
   - Auth0 設定ガイドを削除
   - Auth0 トラブルシューティングを削除

3. **E-3: 不要なスクリプトの削除** [30 ファイル削除]
   - 古いデプロイメントスクリプト（deploy-*.sh）
   - 一時的な migration ログファイル
   - 使用されていないヘルパースクリプト

4. **E-4: 重複設定ディレクトリの削除** [10 ファイル削除]
   - /config/environments/ ディレクトリ全体
   - 標準の config 構造に統一

#### タスクグループ F: 重複コードの共通化
1. **F-1: Application モジュールの共通化** [2 ファイル削減]
   - クラスター接続ロジックを Shared.Infrastructure.ClusterConnector に
   - 各サービスの connect_to_cluster 関数を削除

2. **F-2: Endpoint モジュールの共通化** [2 ファイル削減]
   - ヘルスチェック用 Endpoint を Shared.Web.MinimalEndpoint に
   - 各サービスの重複実装を削除

3. **F-3: エラーハンドリングの統一** [15 ファイル更新]
   - Shared.ErrorHandling モジュールの作成
   - 各サービスの異なるエラー処理パターンを統一

4. **F-4: ログ出力の標準化** [20 ファイル更新]
   - Shared.Logging モジュールの作成
   - 62 箇所の Logger 呼び出しを標準化

#### タスクグループ G: プロセス管理の簡素化
1. **G-1: 不要な GenServer の削除** [5 ファイル削減]
   - RemoteCommandBus → 通常のモジュールに変更
   - RemoteQueryBus → 通常のモジュールに変更
   - NodeConnector → Application 起動時のみに限定

2. **G-2: Supervisor 構造の共通化** [3 ファイル削減]
   - 共通の Supervisor 戦略を Shared.Supervisor.Strategy に定義
   - 各サービスの個別実装を削除

#### タスクグループ H: 依存関係の整理
1. **H-1: Client Service の依存関係削減**
   - phoenix_live_view の削除（GraphQL のみ使用）
   - phoenix_live_dashboard の削除（本番環境で不要）
   - esbuild 関連の削除（フロントエンドは別プロジェクト）
   - dataloader の削除（未使用）

2. **H-2: 共通依存関係の親プロジェクトへの移動**
   - 各サービスで重複している依存関係を統合
   - override 設定の一元管理

3. **H-3: 未使用の OpenTelemetry パッケージ削除**
   - opentelemetry_phoenix の削除
   - opentelemetry_ecto の削除（過剰なトレーシング）

### 📋 依存関係のあるタスク（順次実行）

#### フェーズ 1: 基盤整備
1. **共通設定モジュールの作成**
   - 各サービスで使用する設定を一元管理
   - 環境変数の統一管理

2. **共通エラーハンドリングの実装**
   - 統一的なエラーレスポンス形式
   - ログ出力の標準化

#### フェーズ 2: Web 層の整理
1. **GraphQL スキーマの統合**（B-2 完了後）
   - 共通型定義の抽出
   - リゾルバーの簡素化

2. **REST API の整理**（B-2 完了後）
   - 不要なエンドポイントの削除
   - 認証付きエンドポイントの整理

#### フェーズ 3: 監視・メトリクスの基本実装
1. **Telemetry の簡素化**（A-1, A-2, A-3 完了後）
   - 基本的なメトリクス収集のみ
   - Prometheus エクスポーターの簡素化

2. **ヘルスチェックの統一**（フェーズ 1 完了後）
   - 各サービスで共通のヘルスチェック実装
   - レディネスチェックの簡素化

### 🎯 実装優先度

**最優先（1週目）**:
- タスクグループ B（認証認可）- ユーザー要望
- タスクグループ A（インフラ簡素化）- 基盤整備
- タスクグループ E（ドキュメント・スクリプト整理）- 即座に実行可能
- 型安全性の強化（@spec 追加、behaviour 定義）

**高優先度（2週目）**:
- タスクグループ C（Saga 簡素化）- 大幅なファイル削減
- タスクグループ D（DLQ/CB 簡素化）
- タスクグループ F（重複コードの共通化）
- タスクグループ H（依存関係の整理）

**中優先度（3週目）**:
- フェーズ 1-3 の順次実行タスク
- タスクグループ G（プロセス管理の簡素化）

### 🔧 実装時の注意事項

1. **並列実行時の注意**
   - 各タスクグループは独立して実行可能
   - git のブランチを分けて作業
   - マージ時のコンフリクトに注意

2. **テストの維持**
   - 既存のテストは可能な限り維持
   - 簡素化に伴うテストの更新
   - 新機能には基本的なテストを追加

3. **後方互換性**
   - GraphQL API の互換性維持
   - データベーススキーマの互換性維持
   - 設定ファイルの互換性維持

4. **マイクロサービスアーキテクチャの維持**
   - 3 つのサービス（Command/Query/Client）を維持
   - 3 つのデータベースを維持（学習目的）
   - サービス間通信の明確な分離

### 📏 型安全性とインターフェース設計方針

#### 1. 型システムの強化

##### 全関数への @spec 付与
```elixir
# 悪い例
def process_command(command) do
  # ...
end

# 良い例
@spec process_command(Command.t()) :: {:ok, Event.t()} | {:error, term()}
def process_command(%Command{} = command) do
  # ...
end
```

##### カスタム型の定義
```elixir
defmodule Shared.Types do
  @type command_id :: String.t()
  @type aggregate_id :: String.t()
  @type event_type :: atom()
  @type metadata :: %{optional(atom()) => any()}
  
  @type result(success) :: {:ok, success} | {:error, term()}
  @type result :: result(any())
end
```

#### 2. インターフェースと実装の分離

##### Behaviour によるインターフェース定義
```elixir
# インターフェースファイル: lib/shared/behaviours/event_store.ex
defmodule Shared.Behaviours.EventStore do
  @moduledoc """
  イベントストアのインターフェース定義
  """
  
  @type stream_id :: String.t()
  @type event :: map()
  @type version :: non_neg_integer()
  
  @callback append_events(stream_id(), [event()], version()) :: 
    {:ok, version()} | {:error, term()}
    
  @callback read_stream(stream_id(), version()) :: 
    {:ok, [event()]} | {:error, term()}
    
  @callback subscribe(stream_id(), pid()) :: 
    {:ok, reference()} | {:error, term()}
end

# 実装ファイル: lib/shared/event_store/postgres_adapter.ex
defmodule Shared.EventStore.PostgresAdapter do
  @behaviour Shared.Behaviours.EventStore
  
  @impl true
  @spec append_events(String.t(), [map()], non_neg_integer()) :: 
    {:ok, non_neg_integer()} | {:error, term()}
  def append_events(stream_id, events, expected_version) do
    # PostgreSQL 固有の実装
  end
  
  # 他のコールバック実装...
end
```

##### ファイル構造
```
lib/
├── shared/
│   ├── behaviours/           # インターフェース定義
│   │   ├── event_store.ex
│   │   ├── repository.ex
│   │   ├── saga.ex
│   │   └── projection.ex
│   ├── event_store/          # 実装
│   │   ├── postgres_adapter.ex
│   │   └── in_memory_adapter.ex
│   └── types/                # 共通型定義
│       └── core.ex
```

#### 3. 依存性注入の活用
```elixir
defmodule CommandService.Application do
  def start(_type, _args) do
    children = [
      # インターフェースと実装のバインディング
      {Registry, keys: :unique, name: CommandService.Registry},
      {CommandService.EventStoreAdapter, 
        adapter: Application.get_env(:command_service, :event_store_adapter)}
    ]
    
    opts = [strategy: :one_for_one, name: CommandService.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

#### 4. Dialyzer による型チェック
```elixir
# mix.exs
defp deps do
  [
    {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
    # ...
  ]
end

# .dialyzer_ignore.exs
[
  # 一時的に無視する警告を記載
]
```

#### 5. 実装例：リポジトリパターン
```elixir
# インターフェース
defmodule Shared.Behaviours.Repository do
  @type entity :: struct()
  @type id :: String.t() | integer()
  @type changeset :: Ecto.Changeset.t()
  
  @callback get(id()) :: {:ok, entity()} | {:error, :not_found}
  @callback create(map()) :: {:ok, entity()} | {:error, changeset()}
  @callback update(entity(), map()) :: {:ok, entity()} | {:error, changeset()}
  @callback delete(entity()) :: {:ok, entity()} | {:error, term()}
  @callback list(keyword()) :: [entity()]
end

# 抽象実装
defmodule Shared.Repository do
  defmacro __using__(opts) do
    quote do
      @behaviour Shared.Behaviours.Repository
      
      @schema unquote(opts[:schema])
      @repo unquote(opts[:repo]) || Shared.Repo
      
      @impl true
      @spec get(Shared.Behaviours.Repository.id()) :: 
        {:ok, struct()} | {:error, :not_found}
      def get(id) do
        case @repo.get(@schema, id) do
          nil -> {:error, :not_found}
          entity -> {:ok, entity}
        end
      end
      
      # デフォルト実装を提供
      defoverridable [get: 1]
    end
  end
end
```

## Phase 1: インフラストラクチャ層の整理

### 1.1 イベントストアの簡素化
**現状**: PostgreSQL と InMemory の 2 つのアダプター実装
**改善**:
```elixir
# 単一のイベントストアインターフェース
defmodule Shared.EventStore do
  @behaviour Shared.EventStore.Adapter
  
  # アダプターは設定で切り替え（開発用 InMemory、本番用 Postgres）
  @adapter Application.compile_env(:shared, :event_store_adapter, 
    Shared.EventStore.PostgresAdapter
  )
  
  defdelegate append_events(stream, events), to: @adapter
  defdelegate read_stream(stream), to: @adapter
  defdelegate subscribe(subscriber), to: @adapter
end
```

**削減内容**:
- 複雑なアダプター選択ロジックを削除
- スナップショット機能を基本実装のみに
- イベントアーカイブ機能を削除

### 1.2 Service Discovery の簡素化
**現状**: ServiceRegistry, ServiceRegistrar, ServiceDiscovery の複雑な実装
**改善**:
```elixir
defmodule Shared.ServiceDiscovery do
  # 環境変数ベースのシンプルな実装
  def get_service_url(service) do
    case {service, Application.get_env(:shared, :environment)} do
      {:command_service, :local} -> "http://localhost:8081"
      {:query_service, :local} -> "http://localhost:8082"
      {:client_service, :local} -> "http://localhost:8080"
      {service, :production} -> System.get_env("#{String.upcase(service)}_URL")
    end
  end
end
```

### 1.3 冪等性管理の適正化
**現状**: 5 ファイルの複雑な実装
**改善**: 単一ファイルでのシンプルな実装
```elixir
defmodule Shared.Idempotency do
  use GenServer
  
  # ETS ベースのシンプルなキャッシュ
  def check_and_set(key, ttl_seconds \\ 3600) do
    case :ets.insert_new(@table, {key, :os.system_time(:second) + ttl_seconds}) do
      true -> :ok
      false -> {:error, :duplicate}
    end
  end
end
```

## Phase 2: Saga パターンの適正化

### 2.1 Saga 実装の簡素化
**現状**: 27 ファイルの過剰実装
**目標**: 8-10 ファイルの実用的な実装

```elixir
defmodule Shared.Saga do
  defmodule Definition do
    # Saga の定義を簡潔に記述
    defmacro defsaga(name, do: steps) do
      # マクロで Saga の定義を簡素化
    end
  end
  
  defmodule Executor do
    # 基本的な実行エンジン
    use GenServer
    
    def execute(saga_module, initial_event) do
      # ステートマシンベースの実行
    end
  end
  
  defmodule Store do
    # Saga の状態永続化（シンプルな DB アクセス）
  end
end

# 使用例
defmodule Domain.OrderSaga do
  use Shared.Saga.Definition
  
  defsaga "order_fulfillment" do
    step :reserve_inventory, compensate: :release_inventory
    step :process_payment, compensate: :refund_payment
    step :ship_order
  end
end
```

**削除する機能**:
- SagaTimeoutManager → Executor に統合
- SagaLockManager → 楽観的ロックで十分
- SagaMonitor → 基本的なログとメトリクスで代替

## Phase 3: DLQ とサーキットブレーカーの適正化

### 3.1 Dead Letter Queue のシンプル化
```elixir
defmodule Shared.DeadLetterQueue do
  # 失敗したメッセージの保存と手動リトライのみ
  def push(queue_name, message, error) do
    %{
      queue: queue_name,
      message: message,
      error: inspect(error),
      timestamp: DateTime.utc_now()
    }
    |> Repo.insert!()
  end
  
  def retry(id) do
    # 手動リトライのシンプルな実装
  end
end
```

### 3.2 サーキットブレーカーの基本実装
```elixir
defmodule Shared.CircuitBreaker do
  # Fuse ライブラリを使用したシンプルな実装
  def call(name, fun, opts \\ []) do
    case :fuse.ask(name, :sync) do
      :ok -> 
        try do
          result = fun.()
          :fuse.melt(name)  # 成功したら回路を閉じる
          {:ok, result}
        rescue
          e -> 
            :fuse.blow(name)  # 失敗したら回路を開く
            {:error, e}
        end
      :blown -> {:error, :circuit_open}
    end
  end
end
```

## Phase 4: 認証認可の実装

### 4.1 Firebase Authentication with 役割ベースアクセス制御

#### 実装詳細

##### 1. Firebase Token 検証
```elixir
defmodule Shared.Auth.FirebaseAuth do
  @moduledoc """
  Firebase Authentication トークンの検証
  """
  
  def verify_token(nil), do: {:ok, %{role: :reader}}
  
  def verify_token(token) do
    case FirebaseAdminEx.Auth.verify_id_token(token) do
      {:ok, claims} ->
        user = %{
          uid: claims["uid"],
          email: claims["email"],
          role: determine_role(claims["email"])
        }
        {:ok, user}
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp determine_role(email) do
    admin_email = System.get_env("ADMIN_EMAIL", "")
    
    cond do
      email == admin_email -> :admin
      is_binary(email) -> :writer
      true -> :reader
    end
  end
end
```

##### 2. 権限管理
```elixir
defmodule Shared.Auth.Permissions do
  @moduledoc """
  役割ベースのアクセス制御
  """
  
  @permissions %{
    admin: [:read, :write, :delete, :admin],
    writer: [:read, :write],
    reader: [:read]
  }
  
  def has_permission?(%{role: role}, permission) do
    permission in Map.get(@permissions, role, [])
  end
  
  def has_permission?(nil, :read), do: true
  def has_permission?(nil, _), do: false
end
```

##### 3. GraphQL ミドルウェア
```elixir
defmodule ClientService.GraphQL.Middleware.Authorization do
  @behaviour Absinthe.Middleware
  
  def call(resolution, permission) do
    with %{current_user: user} <- resolution.context,
         true <- Shared.Auth.Permissions.has_permission?(user, permission) do
      resolution
    else
      _ ->
        resolution
        |> Absinthe.Resolution.put_result({:error, "Unauthorized"})
    end
  end
end
```

##### 4. HTTP プラグ
```elixir
defmodule Shared.Auth.AuthPlug do
  import Plug.Conn
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, user} <- Shared.Auth.FirebaseAuth.verify_token(token) do
      assign(conn, :current_user, user)
    else
      _ ->
        # 未認証ユーザーはreaderとして扱う
        assign(conn, :current_user, %{role: :reader})
    end
  end
end
```

#### 設定更新

##### 環境変数
```bash
# .env
ADMIN_EMAIL=your-email@example.com
FIREBASE_PROJECT_ID=elixir-cqrs-es
```

##### Router 更新
```elixir
defmodule ClientServiceWeb.Router do
  use ClientServiceWeb, :router
  
  pipeline :api do
    plug :accepts, ["json"]
    plug Shared.Auth.AuthPlug  # 認証プラグを追加
  end
  
  # GraphQL エンドポイントは全ユーザーアクセス可能
  scope "/" do
    pipe_through :api
    
    forward "/graphql", Absinthe.Plug,
      schema: ClientService.GraphQL.Schema,
      context: %{pubsub: ClientService.PubSub}
  end
end
```

## Phase 5: 監視・メトリクスの基本実装

### 5.1 環境別の監視構成

#### 開発環境
- **トレーシング**: Jaeger (localhost:16686)
- **メトリクス**: Prometheus (localhost:9090)
- **ダッシュボード**: Grafana (localhost:3000)

#### 本番環境（Google Cloud Run）
- **トレーシング**: Cloud Trace（OTLP ネイティブ）
- **メトリクス**: Google Cloud Managed Service for Prometheus
- **ダッシュボード**: Cloud Monitoring

### 5.2 OpenTelemetry 統合
```elixir
defmodule Shared.Telemetry.Config do
  @moduledoc """
  環境に応じた OpenTelemetry 設定
  """
  
  def setup do
    case Application.get_env(:shared, :environment) do
      :production -> setup_cloud_run()
      _ -> setup_local()
    end
  end
  
  defp setup_cloud_run do
    # Google Cloud Trace への OTLP エクスポート
    OpentelemetryOtlp.configure(
      otlp_protocol: :grpc,
      otlp_endpoint: "https://telemetry.googleapis.com:443",
      otlp_headers: [
        {"Authorization", "Bearer #{get_access_token()}"}
      ]
    )
  end
  
  defp setup_local do
    # ローカル Jaeger へのエクスポート
    OpentelemetryOtlp.configure(
      otlp_protocol: :grpc,
      otlp_endpoint: "http://localhost:4317"
    )
  end
end
```

### 5.3 メトリクス収集
```elixir
defmodule Shared.Metrics do
  use GenServer
  
  # 基本的なカウンターとヒストグラム
  def increment(metric, tags \\ []) do
    :telemetry.execute([:event_driven_playground, metric], %{count: 1}, tags)
  end
  
  def timing(metric, fun) do
    start = System.monotonic_time()
    result = fun.()
    duration = System.monotonic_time() - start
    
    :telemetry.execute(
      [:event_driven_playground, metric, :timing],
      %{duration: duration},
      %{}
    )
    
    result
  end
end

# Prometheus エクスポーター（開発・本番共通）
defmodule Shared.Metrics.PrometheusExporter do
  use Plug.Router
  
  plug :match
  plug :dispatch
  
  get "/metrics" do
    metrics = collect_metrics()
    send_resp(conn, 200, format_prometheus(metrics))
  end
end
```

### 5.4 Cloud Run サイドカー設定
```yaml
# cloud-run-with-prometheus.yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: ${SERVICE_NAME}
  annotations:
    run.googleapis.com/launch-stage: BETA
spec:
  template:
    metadata:
      annotations:
        run.googleapis.com/execution-environment: gen2
    spec:
      containers:
      # メインアプリケーション
      - name: app
        image: gcr.io/${PROJECT_ID}/${SERVICE_NAME}:latest
        ports:
        - containerPort: ${PORT}
      
      # Prometheus コレクターサイドカー
      - name: prometheus-sidecar
        image: gcr.io/prometheus-community/prometheus:latest
        args:
          - --config.file=/etc/prometheus/prometheus.yml
          - --storage.tsdb.path=/prometheus
        volumeMounts:
        - name: prometheus-config
          mountPath: /etc/prometheus
      
      volumes:
      - name: prometheus-config
        configMap:
          name: prometheus-config
```

### 5.5 構造化ログ
```elixir
defmodule Shared.Logger do
  require Logger
  
  def info(message, metadata \\ []) do
    Logger.info(message, format_for_cloud_logging(message, metadata))
  end
  
  defp format_for_cloud_logging(message, metadata) do
    # Cloud Logging が認識する JSON 形式
    %{
      message: message,
      severity: "INFO",
      service: Application.get_env(:shared, :service_name),
      environment: Application.get_env(:shared, :environment),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    |> Map.merge(Enum.into(metadata, %{}))
    |> Jason.encode!()
  end
end
```

## Phase 6: ドメイン層の整理

### 6.1 リポジトリパターンの統一
**現状**: Command と Query で重複実装
**改善**: 共通インターフェースと実装の分離

```elixir
defmodule Shared.Repository do
  @doc """基本的な CRUD 操作のマクロ"""
  defmacro __using__(opts) do
    schema = Keyword.fetch!(opts, :schema)
    
    quote do
      def get(id), do: Repo.get(unquote(schema), id)
      def create(attrs), do: unquote(schema).changeset(attrs) |> Repo.insert()
      def update(entity, attrs), do: unquote(schema).changeset(entity, attrs) |> Repo.update()
      def delete(entity), do: Repo.delete(entity)
      
      # 各リポジトリで拡張可能
      defoverridable [get: 1, create: 1, update: 2, delete: 1]
    end
  end
end

# 使用例
defmodule CommandService.ProductRepository do
  use Shared.Repository, schema: CommandService.Product
  
  # カスタムクエリの追加
  def find_by_category(category_id) do
    # ...
  end
end
```

## Phase 7: Web 層の整理

### 7.1 GraphQL スキーマの簡素化
```elixir
defmodule ClientService.GraphQL.Schema do
  use Absinthe.Schema
  
  # 共通の型定義をインポート
  import_types Shared.GraphQL.CommonTypes
  import_types ClientService.GraphQL.ProductTypes
  import_types ClientService.GraphQL.OrderTypes
  
  query do
    import_fields :product_queries
    import_fields :order_queries
  end
  
  mutation do
    import_fields :product_mutations
    import_fields :order_mutations
    
    # 認可ミドルウェアの適用
    middleware ClientService.GraphQL.Middleware.Authorization, :write
  end
end
```

## Phase 8: インフラストラクチャの最適化

### 8.1 Docker の簡素化
```dockerfile
# 共通ベースイメージ
FROM elixir:1.17-alpine AS base
RUN apk add --no-cache build-base git
WORKDIR /app

# 依存関係のキャッシュ
FROM base AS deps
COPY mix.exs mix.lock ./
COPY apps/*/mix.exs ./apps/
RUN mix deps.get --only prod
RUN mix deps.compile

# ビルド
FROM deps AS build
COPY . .
RUN mix compile
ARG SERVICE_NAME
RUN mix release ${SERVICE_NAME}

# 実行イメージ
FROM alpine:3.18
RUN apk add --no-cache libstdc++ openssl ncurses-libs
ARG SERVICE_NAME
COPY --from=build /app/_build/prod/rel/${SERVICE_NAME} /app
CMD ["/app/bin/start"]
```

### 8.2 Google Cloud Run 設定の最適化
```yaml
# cloud-run-service.yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: ${SERVICE_NAME}
  annotations:
    run.googleapis.com/ingress: all
spec:
  template:
    metadata:
      annotations:
        run.googleapis.com/execution-environment: gen2
    spec:
      containers:
      - image: gcr.io/${PROJECT_ID}/${SERVICE_NAME}:latest
        ports:
        - containerPort: ${PORT}
        env:
        - name: SERVICE_NAME
          value: ${SERVICE_NAME}
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: ${SERVICE_NAME}-db-url
              key: url
        resources:
          limits:
            cpu: "1"
            memory: "512Mi"
        livenessProbe:
          httpGet:
            path: /health/live
          periodSeconds: 30
        startupProbe:
          httpGet:
            path: /health/ready
          initialDelaySeconds: 0
          periodSeconds: 10
          failureThreshold: 10
```

### 8.3 Terraform モジュールの整理
```hcl
# terraform/modules/microservice/main.tf
variable "service_name" {}
variable "port" {}
variable "environment" {}

resource "google_cloud_run_service" "service" {
  name     = var.service_name
  location = var.region
  
  template {
    spec {
      containers {
        image = "gcr.io/${var.project_id}/${var.service_name}:latest"
        ports {
          container_port = var.port
        }
      }
    }
  }
}

# 使用例
module "command_service" {
  source       = "./modules/microservice"
  service_name = "command-service"
  port         = 8081
  environment  = "production"
}
```

## 実装の優先順位とファイル数目標

### Phase ごとの削減目標
1. **Phase 1**: インフラ層の整理（30 ファイル削減）
   - EventStore: 15 → 5 ファイル
   - Service Discovery: 8 → 2 ファイル
   - 冪等性: 5 → 1 ファイル

2. **Phase 2**: Saga の適正化（17 ファイル削減）
   - Saga 実装: 27 → 10 ファイル

3. **Phase 3**: DLQ/Circuit Breaker（8 ファイル削減）
   - DLQ: 3 → 1 ファイル
   - Circuit Breaker: 6 → 2 ファイル

4. **Phase 4**: 認証認可（権限モデルの改善）
   - 未ログインユーザーの読み取りアクセス許可
   - 既存 5 ファイルの更新

5. **Phase 5**: 監視・メトリクス（10 ファイル削減）
   - Telemetry: 11 → 6 ファイル（環境別実装を維持）
   - Health Check: 7 → 2 ファイル
   - 本番環境のコンテナを削減

6. **Phase 6**: ドメイン層（20 ファイル削減）
   - リポジトリの統合

7. **Phase 7**: Web 層（10 ファイル削減）
   - GraphQL の整理

8. **Phase 8**: インフラ（Kubernetes 関連削除で 25 ファイル削減）
   - k8s マニフェスト削除
   - Kubernetes 関連スクリプト削除
   - ドキュメント整理

9. **Phase 9**: 追加の整理（55 ファイル削減）
   - 不要なスクリプト・ログ: 30 ファイル削除
   - 重複コードの共通化: 10 ファイル削減
   - プロセス管理の簡素化: 8 ファイル削減
   - 空ファイル・未使用モジュール: 7 ファイル削除

**目標**: 260 ファイル → 70-90 ファイル（約 70% 削減）

## 期待される成果

### 学習効果の向上
- **理解しやすさ**: 各技術要素の本質が見える
- **実験しやすさ**: 変更の影響範囲が明確
- **デバッグ容易性**: シンプルな実装で問題箇所の特定が容易
- **型安全性**: @spec と Dialyzer によるコンパイル時チェック

### 実用性の維持
- **マイクロサービス**: 3 サービス構成を維持
- **本番デプロイ可能**: 必要最小限のインフラ設定
- **拡張性**: 学習後に機能追加が容易
- **保守性**: インターフェースと実装の分離による変更容易性

## まとめ

このバランス型リファクタリングにより、学習用プロジェクトとしての価値を最大化しながら、実用的なマイクロサービスアーキテクチャを維持します。各技術要素は「ちょうど良い」レベルで実装され、概念の理解と実践的な経験の両方を得られる構成となります。

### 主な変更点
1. **認証**: ~~Auth0 → Firebase Authentication~~ （移行済み）
2. **認可**: ドメイン全体の認証制限を解除、役割ベースアクセス制御を実装
3. **インフラ**: Kubernetes 削除、Google Cloud Run に完全移行
4. **開発環境**: pgweb は開発環境のみ、本番環境では不使用
5. **監視・メトリクス**: 
   - 開発: Jaeger/Prometheus/Grafana
   - 本番: Cloud Trace/Managed Prometheus/Cloud Monitoring

### 削減効果
- Kubernetes 関連: 約 15-20 ファイル削減
- 認証の簡素化: 約 5 ファイル削減
- 不要スクリプト・設定: 約 40 ファイル削減
- 重複コードの共通化: 約 25 ファイル削減
- プロセス管理の簡素化: 約 10 ファイル削減
- 全体で約 70% のファイル削減を達成見込み