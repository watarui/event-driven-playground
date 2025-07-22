defmodule CommandService.Domain.Models.Category do
  @moduledoc """
  カテゴリーエンティティ

  コマンドサービス側で使用するカテゴリーのドメインモデル
  """

  @enforce_keys [:id, :name, :created_at]
  defstruct [
    :id,
    :name,
    :description,
    :created_at,
    :updated_at
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          description: String.t() | nil,
          created_at: DateTime.t(),
          updated_at: DateTime.t() | nil
        }

  @doc """
  新しいカテゴリーを作成する
  """
  @spec new(String.t(), String.t(), String.t() | nil) :: {:ok, t()} | {:error, atom()}
  def new(id, name, description \\ nil) do
    with :ok <- validate_name(name) do
      {:ok,
       %__MODULE__{
         id: id,
         name: name,
         description: description,
         created_at: DateTime.utc_now(),
         updated_at: DateTime.utc_now()
       }}
    end
  end

  @doc """
  カテゴリー情報を更新する
  """
  @spec update(t(), map()) :: {:ok, t()} | {:error, atom()}
  def update(%__MODULE__{} = category, attrs) do
    updated_category = %{category | updated_at: DateTime.utc_now()}

    updated_category =
      Enum.reduce(attrs, updated_category, fn
        {:name, value}, acc ->
          case validate_name(value) do
            :ok -> %{acc | name: value}
            _ -> acc
          end

        {:description, value}, acc ->
          %{acc | description: value}

        _, acc ->
          acc
      end)

    {:ok, updated_category}
  end

  @doc """
  カテゴリー名を変更する
  """
  @spec rename(t(), String.t()) :: {:ok, t()} | {:error, atom()}
  def rename(%__MODULE__{} = category, new_name) do
    update(category, %{name: new_name})
  end

  @doc """
  説明を更新する
  """
  @spec update_description(t(), String.t() | nil) :: {:ok, t()}
  def update_description(%__MODULE__{} = category, description) do
    update(category, %{description: description})
  end

  # Private functions

  defp validate_name(name) when is_binary(name) and byte_size(name) > 0 do
    if byte_size(name) <= 100 do
      :ok
    else
      {:error, :name_too_long}
    end
  end

  defp validate_name(_), do: {:error, :invalid_name}
end
