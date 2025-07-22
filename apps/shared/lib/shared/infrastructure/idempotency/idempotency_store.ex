defmodule Shared.Infrastructure.Idempotency.IdempotencyStore do
  @moduledoc """
  冪等性を保証するためのストア（Firestore版）

  同じ冪等性キーで複数回実行された場合、最初の結果を返します。
  """

  alias Shared.Infrastructure.Firestore.Repository
  require Logger

  @collection "idempotency"
  # 24時間
  @default_ttl_seconds 86_400

  @doc """
  冪等性キーを使用して処理を実行する

  - すでに実行済みの場合は、保存された結果を返す
  - 実行中の場合は、完了を待つ
  - 未実行の場合は、処理を実行して結果を保存する
  """
  @spec execute(String.t(), integer(), fun()) :: {:ok, any()} | {:error, any()}
  def execute(idempotency_key, ttl_seconds \\ @default_ttl_seconds, fun)
      when is_function(fun, 0) do
    case check_and_lock(idempotency_key) do
      {:ok, :locked} ->
        # 処理を実行
        result =
          try do
            fun.()
          rescue
            e ->
              {:error, e}
          end

        # 結果を保存
        save_result(idempotency_key, result, ttl_seconds)
        result

      {:ok, {:completed, result}} ->
        # すでに完了している場合は保存された結果を返す
        Logger.info("Idempotency hit for key: #{idempotency_key}")
        result

      {:ok, :processing} ->
        # 処理中の場合は少し待ってからリトライ
        Process.sleep(100)
        execute(idempotency_key, ttl_seconds, fun)

      {:error, reason} ->
        Logger.error("Failed to check idempotency: #{inspect(reason)}")
        # エラーの場合は処理を実行（at-least-once を保証）
        fun.()
    end
  end

  defp check_and_lock(idempotency_key) do
    now = DateTime.utc_now()

    case Repository.get(@collection, idempotency_key) do
      {:ok, nil} ->
        # 新規の場合はロックを作成
        lock_data = %{
          status: "processing",
          started_at: now,
          updated_at: now
        }

        case Repository.save(@collection, idempotency_key, lock_data) do
          {:ok, _} -> {:ok, :locked}
          error -> error
        end

      {:ok, data} ->
        case data["status"] do
          "completed" ->
            # 完了済み
            result = decode_result(data["result"])
            {:ok, {:completed, result}}

          "processing" ->
            # 処理中
            started_at = parse_datetime(data["started_at"])

            # タイムアウトチェック（5分）
            if DateTime.diff(now, started_at, :second) > 300 do
              # タイムアウトした場合は再実行
              check_and_lock_retry(idempotency_key)
            else
              {:ok, :processing}
            end

          _ ->
            # 不明なステータスの場合は再実行
            check_and_lock_retry(idempotency_key)
        end

      error ->
        error
    end
  end

  defp check_and_lock_retry(idempotency_key) do
    now = DateTime.utc_now()

    lock_data = %{
      status: "processing",
      started_at: now,
      updated_at: now
    }

    case Repository.save(@collection, idempotency_key, lock_data) do
      {:ok, _} -> {:ok, :locked}
      error -> error
    end
  end

  defp save_result(idempotency_key, result, ttl_seconds) do
    now = DateTime.utc_now()
    expires_at = DateTime.add(now, ttl_seconds, :second)

    data = %{
      status: "completed",
      result: encode_result(result),
      completed_at: now,
      updated_at: now,
      expires_at: expires_at
    }

    Repository.save(@collection, idempotency_key, data)
  end

  defp encode_result({:ok, value}), do: %{type: "ok", value: value}
  defp encode_result({:error, reason}), do: %{type: "error", reason: inspect(reason)}
  defp encode_result(other), do: %{type: "other", value: inspect(other)}

  defp decode_result(%{"type" => "ok", "value" => value}), do: {:ok, value}
  defp decode_result(%{"type" => "error", "reason" => reason}), do: {:error, reason}
  defp decode_result(%{"type" => "other", "value" => value}), do: value
  defp decode_result(nil), do: nil

  defp parse_datetime(nil), do: DateTime.utc_now()
  defp parse_datetime(%DateTime{} = dt), do: dt

  defp parse_datetime(string) when is_binary(string) do
    case DateTime.from_iso8601(string) do
      {:ok, datetime, _} -> datetime
      _ -> DateTime.utc_now()
    end
  end

  defp parse_datetime(_), do: DateTime.utc_now()

  @doc """
  期限切れのエントリをクリーンアップ
  """
  def cleanup_expired do
    # TODO: Firestore のクエリ機能を使用して期限切れエントリを削除
    :ok
  end
end
