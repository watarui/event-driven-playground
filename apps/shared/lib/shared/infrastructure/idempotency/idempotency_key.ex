defmodule Shared.Infrastructure.Idempotency.IdempotencyKey do
  @moduledoc """
  冪等性キーの生成とTTL管理
  """

  @doc """
  コマンドから冪等性キーを生成
  """
  @spec generate(String.t(), String.t(), String.t(), map()) :: String.t()
  def generate(command_type, aggregate_id, user_id, params) do
    # パラメータを決定的な順序でシリアライズ
    params_string =
      params
      |> Enum.sort_by(fn {k, _v} -> to_string(k) end)
      |> Enum.map_join(",", fn {k, v} -> "#{k}:#{v}" end)

    # SHA256でハッシュ化
    data = "#{command_type}|#{aggregate_id}|#{user_id}|#{params_string}"

    :crypto.hash(:sha256, data)
    |> Base.encode16(case: :lower)
  end

  @doc """
  操作タイプに基づいてTTL（秒）を返す
  """
  @spec ttl_seconds(String.t()) :: integer()
  # 24時間
  def ttl_seconds("command"), do: 86_400
  # 1時間
  def ttl_seconds("query"), do: 3_600
  # デフォルト24時間
  def ttl_seconds(_), do: 86_400
end
