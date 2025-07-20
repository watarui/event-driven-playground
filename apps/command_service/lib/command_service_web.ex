defmodule CommandServiceWeb do
  @moduledoc """
  Command Service の Web インターフェース
  ヘルスチェックエンドポイントのみを提供
  """

  use Plug.Router

  plug(Plug.Logger)
  plug(:match)
  plug(:dispatch)

  # ヘルスチェックエンドポイント
  get "/health" do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(
      200,
      Jason.encode!(%{status: "ok", service: "command_service", timestamp: DateTime.utc_now()})
    )
  end

  # 404 ハンドラー
  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
