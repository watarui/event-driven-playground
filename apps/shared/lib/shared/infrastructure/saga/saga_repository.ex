defmodule Shared.Infrastructure.Saga.SagaRepository do
  @moduledoc """
  Saga インスタンスの永続化を管理するリポジトリ

  Firestore を使用して Saga の状態を保存・取得します。
  """

  alias Shared.Infrastructure.Firestore.Repository
  require Logger

  @collection "sagas"

  @doc """
  Saga を保存
  """
  def save_saga(saga_data) do
    entity = prepare_saga_entity(saga_data)

    case Repository.save(@collection, saga_data.saga_id, entity) do
      :ok ->
        Logger.debug("Saga saved: saga_id=#{saga_data.saga_id}")
        :ok

      {:error, reason} = error ->
        Logger.error(
          "Failed to save saga: saga_id=#{saga_data.saga_id}, reason=#{inspect(reason)}"
        )

        error
    end
  end

  @doc """
  Saga を取得
  """
  def get_saga(saga_id) do
    case Repository.get(@collection, saga_id) do
      {:ok, entity} when not is_nil(entity) ->
        saga_data = restore_saga_data(entity)
        {:ok, saga_data}

      {:ok, nil} ->
        {:error, :not_found}

      {:error, reason} = error ->
        Logger.error("Failed to get saga: saga_id=#{saga_id}, reason=#{inspect(reason)}")
        error
    end
  end

  @doc """
  アクティブな Saga を取得
  """
  def get_active_sagas do
    filters = [
      {:field, "status", :in, ["running", "compensating"]}
    ]

    case Repository.query(@collection, filters) do
      {:ok, entities} ->
        sagas = Enum.map(entities, &restore_saga_data/1)
        {:ok, sagas}

      {:error, reason} = error ->
        Logger.error("Failed to get active sagas: reason=#{inspect(reason)}")
        error
    end
  end

  @doc """
  Saga 名でアクティブな Saga を取得
  """
  def get_active_sagas_by_name(saga_name) do
    filters = [
      {:field, "saga_name", :==, saga_name},
      {:field, "status", :in, ["running", "compensating"]}
    ]

    case Repository.query(@collection, filters) do
      {:ok, entities} ->
        sagas = Enum.map(entities, &restore_saga_data/1)
        {:ok, sagas}

      {:error, reason} = error ->
        Logger.error(
          "Failed to get active sagas by name: saga_name=#{saga_name}, reason=#{inspect(reason)}"
        )

        error
    end
  end

  @doc """
  Saga を削除
  """
  def delete_saga(saga_id) do
    case Repository.delete(@collection, saga_id) do
      :ok ->
        Logger.debug("Saga deleted: saga_id=#{saga_id}")
        :ok

      {:error, reason} = error ->
        Logger.error("Failed to delete saga: saga_id=#{saga_id}, reason=#{inspect(reason)}")
        error
    end
  end

  @doc """
  古い完了済み Saga を削除
  """
  def cleanup_completed_sagas(days_to_keep \\ 30) do
    cutoff_date = DateTime.add(DateTime.utc_now(), -days_to_keep * 24 * 60 * 60, :second)

    filters = [
      {:field, "status", :in, ["completed", "failed"]},
      {:field, "updated_at", :<, cutoff_date}
    ]

    case Repository.query(@collection, filters) do
      {:ok, entities} ->
        deleted_count =
          entities
          |> Enum.map(fn entity ->
            saga_id = Map.get(entity, :id) || Map.get(entity, "id")
            delete_saga(saga_id)
            saga_id
          end)
          |> length()

        Logger.info("Cleaned up #{deleted_count} old sagas")
        {:ok, deleted_count}

      {:error, reason} = error ->
        Logger.error("Failed to cleanup completed sagas: reason=#{inspect(reason)}")
        error
    end
  end

  @doc """
  Saga の統計情報を取得
  """
  def get_saga_statistics do
    try do
      # 各ステータスの件数を取得
      statuses = ["running", "compensating", "completed", "failed"]

      stats =
        Enum.reduce(statuses, %{}, fn status, acc ->
          filters = [{:field, "status", :==, status}]

          case Repository.query(@collection, filters, limit: 1) do
            {:ok, entities} ->
              # Firestore では count クエリが直接サポートされていないため、
              # 実際のカウントは別途実装が必要
              Map.put(acc, String.to_atom(status), length(entities))

            {:error, _} ->
              Map.put(acc, String.to_atom(status), 0)
          end
        end)

      {:ok, stats}
    rescue
      e ->
        Logger.error("Failed to get saga statistics: #{inspect(e)}")
        {:error, :statistics_error}
    end
  end

  @doc """
  特定の集約に関連する Saga を取得
  """
  def get_sagas_by_aggregate(aggregate_id) do
    # saga_state 内の order_id などで検索する必要があるが、
    # Firestore ではネストされたフィールドの検索に制限があるため、
    # saga_id のパターンマッチングで対応

    case Repository.list(@collection) do
      {:ok, entities} ->
        filtered_sagas =
          entities
          |> Enum.filter(fn entity ->
            saga_id = Map.get(entity, :id) || Map.get(entity, "id")
            String.contains?(saga_id, aggregate_id)
          end)
          |> Enum.map(&restore_saga_data/1)

        {:ok, filtered_sagas}

      {:error, reason} = error ->
        Logger.error(
          "Failed to get sagas by aggregate: aggregate_id=#{aggregate_id}, reason=#{inspect(reason)}"
        )

        error
    end
  end

  # Private Functions

  defp prepare_saga_entity(saga_data) do
    %{
      saga_id: saga_data.saga_id,
      saga_name: saga_data.saga_name,
      saga_state: encode_saga_state(saga_data.saga_state),
      current_step: to_string(saga_data.current_step || ""),
      current_step_index: saga_data.current_step_index,
      status: to_string(saga_data.status),
      failure_reason: encode_failure_reason(saga_data.failure_reason),
      retry_count: encode_retry_count(saga_data.retry_count),
      started_at: saga_data.started_at,
      updated_at: saga_data.updated_at,
      step_started_at: saga_data.step_started_at,
      compensation_index: saga_data.compensation_index
    }
  end

  defp restore_saga_data(entity) do
    %{
      saga_id: Map.get(entity, :saga_id) || Map.get(entity, "saga_id"),
      saga_name: Map.get(entity, :saga_name) || Map.get(entity, "saga_name"),
      saga_state:
        decode_saga_state(Map.get(entity, :saga_state) || Map.get(entity, "saga_state")),
      current_step:
        decode_atom(Map.get(entity, :current_step) || Map.get(entity, "current_step")),
      current_step_index:
        Map.get(entity, :current_step_index) || Map.get(entity, "current_step_index"),
      status: Map.get(entity, :status) || Map.get(entity, "status"),
      failure_reason:
        decode_failure_reason(
          Map.get(entity, :failure_reason) || Map.get(entity, "failure_reason")
        ),
      retry_count:
        decode_retry_count(Map.get(entity, :retry_count) || Map.get(entity, "retry_count")),
      started_at: Map.get(entity, :started_at) || Map.get(entity, "started_at"),
      updated_at: Map.get(entity, :updated_at) || Map.get(entity, "updated_at"),
      step_started_at: Map.get(entity, :step_started_at) || Map.get(entity, "step_started_at"),
      compensation_index:
        Map.get(entity, :compensation_index) || Map.get(entity, "compensation_index")
    }
  end

  defp encode_saga_state(saga_state) when is_map(saga_state) do
    # Map を JSON 互換の形式に変換
    saga_state
    |> Enum.map(fn {k, v} -> {to_string(k), encode_value(v)} end)
    |> Enum.into(%{})
  end

  defp encode_saga_state(nil), do: %{}

  defp decode_saga_state(saga_state) when is_map(saga_state) do
    # JSON 形式から Map に復元
    saga_state
    |> Enum.map(fn {k, v} -> {String.to_atom(k), decode_value(v)} end)
    |> Enum.into(%{})
  end

  defp decode_saga_state(nil), do: %{}

  defp encode_value(value) when is_atom(value), do: to_string(value)
  defp encode_value(value) when is_list(value), do: Enum.map(value, &encode_value/1)

  defp encode_value(value) when is_map(value) do
    value
    |> Enum.map(fn {k, v} -> {to_string(k), encode_value(v)} end)
    |> Enum.into(%{})
  end

  defp encode_value(value), do: value

  defp decode_value(value) when is_list(value), do: Enum.map(value, &decode_value/1)

  defp decode_value(value) when is_map(value) do
    value
    |> Enum.map(fn {k, v} -> {decode_key(k), decode_value(v)} end)
    |> Enum.into(%{})
  end

  defp decode_value(value), do: value

  defp decode_key(key) when is_binary(key) do
    # 数値文字列をアトムに変換しない
    if String.match?(key, ~r/^\d+$/) do
      key
    else
      String.to_atom(key)
    end
  end

  defp decode_key(key), do: key

  defp encode_failure_reason(nil), do: nil
  defp encode_failure_reason(reason) when is_atom(reason), do: to_string(reason)
  defp encode_failure_reason(reason) when is_binary(reason), do: reason
  defp encode_failure_reason(reason), do: inspect(reason)

  defp decode_failure_reason(nil), do: nil

  defp decode_failure_reason(reason) when is_binary(reason) do
    # 一般的なエラーアトムに変換を試みる
    case reason do
      "timeout" -> :timeout
      "insufficient_stock" -> :insufficient_stock
      "insufficient_funds" -> :insufficient_funds
      "invalid_payment_method" -> :invalid_payment_method
      "fraud_detected" -> :fraud_detected
      "invalid_address" -> :invalid_address
      "restricted_area" -> :restricted_area
      _ -> reason
    end
  end

  defp decode_failure_reason(reason), do: reason

  defp encode_retry_count(retry_count) when is_map(retry_count) do
    retry_count
    |> Enum.map(fn {k, v} -> {to_string(k), v} end)
    |> Enum.into(%{})
  end

  defp encode_retry_count(nil), do: %{}

  defp decode_retry_count(retry_count) when is_map(retry_count) do
    retry_count
    |> Enum.map(fn {k, v} -> {decode_atom(k), v} end)
    |> Enum.into(%{})
  end

  defp decode_retry_count(nil), do: %{}

  defp decode_atom(nil), do: nil
  defp decode_atom(""), do: nil
  defp decode_atom(value) when is_binary(value), do: String.to_atom(value)
  defp decode_atom(value) when is_atom(value), do: value
end
