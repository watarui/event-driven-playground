defmodule Shared.Infrastructure.Idempotency.IdempotencyKey do
  @moduledoc """
  べき等性キーを管理するためのモジュール

  コマンドやリクエストのべき等性キーを生成・検証する機能を提供
  """

  @doc """
  べき等性キーを生成する

  ## Parameters
  - `context` - コンテキスト（例: "command", "saga_step"）
  - `identifier` - 一意識別子（例: aggregate_id, saga_id）
  - `operation` - 操作名（例: "create_order", "reserve_inventory"）
  - `params` - パラメータ（ハッシュ化される）

  ## Examples
      iex> IdempotencyKey.generate("command", "order-123", "create", %{amount: 100})
      "command:order-123:create:a1b2c3d4..."
  """
  @spec generate(String.t(), String.t(), String.t(), map() | nil) :: String.t()
  def generate(context, identifier, operation, params \\ nil) do
    params_hash = if params, do: hash_params(params), else: ""

    [context, identifier, operation, params_hash]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(":")
  end

  @doc """
  べき等性キーを解析する
  """
  @spec parse(String.t()) :: {:ok, map()} | {:error, :invalid_format}
  def parse(key) do
    case String.split(key, ":") do
      [context, identifier, operation] ->
        {:ok,
         %{
           context: context,
           identifier: identifier,
           operation: operation,
           params_hash: nil
         }}

      [context, identifier, operation, params_hash] ->
        {:ok,
         %{
           context: context,
           identifier: identifier,
           operation: operation,
           params_hash: params_hash
         }}

      _ ->
        {:error, :invalid_format}
    end
  end

  @doc """
  べき等性キーの有効期限を取得（秒）

  コンテキストに応じて異なるTTLを返す
  """
  @spec ttl_seconds(String.t()) :: non_neg_integer()
  # 1時間
  def ttl_seconds("command"), do: 3600
  # 2時間
  def ttl_seconds("saga_step"), do: 7200
  # 5分
  def ttl_seconds("api_request"), do: 300
  # デフォルト30分
  def ttl_seconds(_), do: 1800

  # Private functions

  defp hash_params(params) when is_map(params) do
    params
    |> Jason.encode!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    # 最初の8文字のみ使用
    |> String.slice(0..7)
  end

  defp hash_params(_), do: ""
end
