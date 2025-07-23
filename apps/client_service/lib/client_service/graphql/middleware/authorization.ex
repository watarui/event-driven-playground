defmodule ClientService.GraphQL.Middleware.Authorization do
  @moduledoc """
  GraphQL の認可ミドルウェア
  各フィールドやミューテーションに必要な権限をチェックする
  """
  @behaviour Absinthe.Middleware

  alias Shared.Auth.Permissions

  @impl true
  def call(resolution, permission) do
    context = resolution.context || %{}
    current_user = Map.get(context, :current_user)

    # デバッグログを追加
    require Logger
    Logger.info("Authorization check - permission: #{inspect(permission)}, current_user: #{inspect(current_user)}")
    
    if Permissions.has_permission?(current_user, permission) do
      resolution
    else
      error_message =
        case {current_user, permission} do
          {nil, :read} ->
            # 読み取り権限は全員に許可されているはずなので、ここには来ないはず
            "内部エラーが発生しました"

          {nil, _} ->
            "この操作には認証が必要です"

          {_, permission} ->
            "権限が不足しています: #{permission} 権限が必要です"
        end

      resolution
      |> Absinthe.Resolution.put_result({:error, error_message})
    end
  end
end
