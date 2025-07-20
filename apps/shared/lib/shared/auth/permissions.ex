defmodule Shared.Auth.Permissions do
  @moduledoc """
  役割ベースのアクセス制御
  - admin: 全ての操作が可能
  - writer: 読み取りと書き込みが可能
  - reader: 読み取りのみ可能（未ログインユーザーのデフォルト）
  """

  @type role :: :admin | :writer | :reader
  @type permission :: :read | :write | :delete | :admin

  @permissions %{
    admin: [:read, :write, :delete, :admin],
    writer: [:read, :write],
    reader: [:read]
  }

  @doc """
  ユーザーが指定された権限を持っているかチェック
  """
  @spec has_permission?(map() | nil, permission()) :: boolean()
  def has_permission?(nil, :read), do: true
  def has_permission?(nil, _), do: false

  def has_permission?(%{role: role}, permission) do
    permission in Map.get(@permissions, role, [])
  end

  def has_permission?(%{user_role: role}, permission) do
    # user_role フィールドの場合も対応
    permission in Map.get(@permissions, role, [])
  end

  def has_permission?(_, _), do: false

  @doc """
  ユーザーのロールを決定
  """
  @spec determine_role(String.t() | nil) :: role()
  def determine_role(email) when is_binary(email) do
    admin_email = System.get_env("ADMIN_EMAIL", "")

    if email == admin_email && admin_email != "" do
      :admin
    else
      :writer
    end
  end

  def determine_role(_), do: :reader
end
