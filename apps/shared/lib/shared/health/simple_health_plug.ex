defmodule Shared.Health.SimpleHealthPlug do
  @moduledoc """
  シンプルなヘルスチェックエンドポイント用の Plug
  データベース接続などの依存関係を持たない単純な応答を返します。
  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%{path_info: ["health"]} = conn, opts) do
    service_name = Keyword.get(opts, :service_name, "unknown")
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{
      status: "ok", 
      timestamp: DateTime.utc_now(),
      service: service_name
    }))
  end
  
  # forwardからの呼び出しの場合、path_infoが空になることがある
  def call(%{path_info: []} = conn, opts) do
    service_name = Keyword.get(opts, :service_name, "unknown")
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{
      status: "ok", 
      timestamp: DateTime.utc_now(),
      service: service_name
    }))
  end

  def call(%{path_info: ["health", "live"]} = conn, _opts) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "OK")
  end

  def call(%{path_info: ["health", "ready"]} = conn, _opts) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "Ready")
  end

  def call(conn, _opts) do
    conn
  end
end