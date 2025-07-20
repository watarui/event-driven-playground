defmodule ClientServiceWeb.Router do
  use ClientServiceWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {ClientServiceWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
    plug(ClientServiceWeb.Plugs.DataloaderPlug)
  end

  pipeline :graphiql do
    plug(:accepts, ["html", "json"])
    plug(ClientServiceWeb.Plugs.GraphiQLAuthPlug)
  end

  pipeline :authenticated_api do
    plug(:accepts, ["json"])
    plug(ClientService.Auth.AdaptivePlug)
    plug(ClientService.Auth.ContextPlug)
    plug(ClientServiceWeb.Plugs.DataloaderPlug)
  end

  pipeline :metrics do
    plug(:accepts, ["text", "plain"])
  end

  # ヘルスチェックエンドポイント
  forward("/health", Shared.Health.SimpleHealthPlug, service_name: "client_service")

  # GraphQL エンドポイント
  scope "/" do
    pipe_through(:authenticated_api)

    forward("/graphql", Absinthe.Plug,
      schema: ClientService.GraphQL.Schema,
      context: %{pubsub: ClientService.PubSub}
    )
  end

  # GraphiQL エンドポイント（HTML と JSON を受け付ける）
  scope "/" do
    pipe_through(:graphiql)

    # GET リクエストは GraphiQL UI を返す
    get("/graphiql", Absinthe.Plug.GraphiQL,
      schema: ClientService.GraphQL.Schema,
      interface: :simple,
      socket: ClientServiceWeb.AbsintheSocket,
      context: %{pubsub: ClientService.PubSub}
    )

    # POST リクエストは GraphQL クエリを処理
    post("/graphiql", Absinthe.Plug,
      schema: ClientService.GraphQL.Schema,
      context: %{pubsub: ClientService.PubSub}
    )
  end

  # Prometheus メトリクスエンドポイント（一時的に無効化）
  # TODO: PrometheusPlug を実装後に有効化
  # scope "/metrics" do
  #   pipe_through(:metrics)
  #   forward("/", Shared.Telemetry.Metrics.PrometheusPlug)
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:client_service, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: ClientServiceWeb.Telemetry)
    end
  end
end
