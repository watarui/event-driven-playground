defmodule QueryService.Application.Queries.BaseQuery do
  @moduledoc """
  すべてのクエリの基底モジュール

  クエリの共通的な振る舞いと構造を定義します
  """

  @callback validate(map()) :: {:ok, struct()} | {:error, String.t()}
  @callback query_type() :: String.t()

  defmacro __using__(_opts) do
    quote do
      @behaviour QueryService.Application.Queries.BaseQuery

      @doc """
      クエリのメタデータを作成する
      """
      def create_metadata(user_id \\ nil, metadata \\ %{}) do
        %{
          query_id: UUID.uuid4(),
          query_type: query_type(),
          user_id: user_id,
          queried_at: DateTime.utc_now(),
          metadata: metadata
        }
      end

      defimpl Jason.Encoder do
        def encode(query, opts) do
          query
          |> Map.from_struct()
          |> Map.reject(fn {_k, v} -> is_nil(v) end)
          |> Jason.Encode.map(opts)
        end
      end
    end
  end
end
