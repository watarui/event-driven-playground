defmodule ClientService.Auth.FirebaseAuthBehaviour do
  @moduledoc """
  Firebase 認証のビヘイビア定義
  """

  @type user_info :: %{
          user_id: String.t(),
          email: String.t() | nil,
          email_verified: boolean(),
          name: String.t() | nil,
          picture: String.t() | nil,
          role: atom(),
          roles: list(String.t()),
          is_admin: boolean(),
          claims: map()
        }

  @callback verify_token(token :: String.t()) :: {:ok, user_info()} | {:error, atom()}
  @callback build_user_info(claims :: map()) :: user_info()
  @callback get_user_role(claims :: map()) :: atom()
end