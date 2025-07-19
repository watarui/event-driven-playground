defmodule ClientService.GraphQL.Types.Common do
  @moduledoc """
  共通の GraphQL 型定義
  """

  use Absinthe.Schema.Notation

  @desc "JSON 型"
  scalar :json, name: "JSON" do
    serialize(&encode_json/1)
    parse(&decode_json/1)
  end

  defp encode_json(value) when is_binary(value) do
    # すでに JSON 文字列の場合はそのまま返す
    case Jason.decode(value) do
      {:ok, _} -> value
      {:error, _} -> Jason.encode!(value)
    end
  end

  defp encode_json(value) do
    # データ構造を JSON シリアライズ可能な形式に変換
    sanitized_value = sanitize_for_json(value)
    Jason.encode!(sanitized_value)
  rescue
    e ->
      # エンコードに失敗した場合は、エラー情報を含む JSON を返す
      Jason.encode!(%{
        error: "Failed to encode value",
        message: inspect(e),
        original_type: inspect(value)
      })
  end

  # JSON シリアライズ可能な形式に変換
  defp sanitize_for_json(value) when is_map(value) do
    value
    |> Enum.map(fn {k, v} -> {to_string(k), sanitize_for_json(v)} end)
    |> Enum.into(%{})
  end

  defp sanitize_for_json(value) when is_list(value) do
    Enum.map(value, &sanitize_for_json/1)
  end

  defp sanitize_for_json(value) when is_tuple(value) do
    value
    |> Tuple.to_list()
    |> Enum.map(&sanitize_for_json/1)
  end

  defp sanitize_for_json(value)
       when is_atom(value) and not is_nil(value) and not is_boolean(value) do
    to_string(value)
  end

  defp sanitize_for_json(%{__struct__: _} = struct) do
    struct
    |> Map.from_struct()
    |> Map.delete(:__meta__)
    |> sanitize_for_json()
  end

  defp sanitize_for_json(value) do
    value
  end

  defp decode_json(%Absinthe.Blueprint.Input.String{value: value}) do
    case Jason.decode(value) do
      {:ok, result} -> {:ok, result}
      _ -> {:ok, value}
    end
  end

  defp decode_json(%Absinthe.Blueprint.Input.Null{}) do
    {:ok, nil}
  end

  defp decode_json(_) do
    :error
  end

  @desc "ソート順"
  enum :sort_order do
    value(:asc, description: "昇順")
    value(:desc, description: "降順")
  end

  @desc "削除結果"
  object :delete_result do
    field(:success, non_null(:boolean))
    field(:message, :string)
  end

  @desc "エラー詳細"
  object :error_detail do
    field(:field, :string)
    field(:message, non_null(:string))
  end

  @desc "操作結果"
  interface :result do
    field(:success, non_null(:boolean))
    field(:errors, list_of(:error_detail))

    resolve_type(fn
      %{__typename: type}, _ -> type
      _, _ -> nil
    end)
  end
end
