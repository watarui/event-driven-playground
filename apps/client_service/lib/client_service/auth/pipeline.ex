defmodule ClientService.Auth.Pipeline do
  @moduledoc """
  Guardian 認証パイプライン
  """
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    Logger.info("Auth.Pipeline called")

    # Authorization ヘッダーをチェック
    auth_header = Plug.Conn.get_req_header(conn, "authorization")
    Logger.info("Authorization header: #{inspect(auth_header)}")

    conn
    |> Guardian.Plug.VerifyHeader.call(
      Guardian.Plug.VerifyHeader.init(
        module: ClientService.Auth.Guardian,
        error_handler: ClientService.Auth.ErrorHandler,
        scheme: "Bearer"
      )
    )
    |> Guardian.Plug.LoadResource.call(
      Guardian.Plug.LoadResource.init(
        module: ClientService.Auth.Guardian,
        error_handler: ClientService.Auth.ErrorHandler,
        allow_blank: true
      )
    )
  end
end
