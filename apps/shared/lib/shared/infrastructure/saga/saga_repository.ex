defmodule Shared.Infrastructure.Saga.SagaRepository do
  @moduledoc """
  SAGA の永続化を管理するリポジトリ

  SAGA の状態を PostgreSQL に保存し、障害時の復旧を可能にします
  """

  alias Shared.Infrastructure.EventStore.Repo
  import Ecto.Query

  require Logger

  @doc """
  SAGA の状態を保存する
  """
  def save(saga_state) when is_struct(saga_state, Shared.Infrastructure.Saga.SagaState) do
    save_saga(saga_state.id, Map.from_struct(saga_state))
  end

  def save_saga(saga_id, saga_state) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:microsecond)

    # created_at フィールドの値を決定（started_at フィールドも考慮）
    created_at =
      convert_to_naive_datetime(saga_state[:created_at]) ||
        convert_to_naive_datetime(saga_state[:started_at]) ||
        now

    # UUID を適切な形式に変換
    uuid_binary = convert_uuid_to_binary(saga_id)

    saga_record = %{
      id: uuid_binary,
      saga_type: saga_state[:saga_type] || "OrderSaga",
      state: Jason.encode!(saga_state),
      current_step: to_string(saga_state[:current_step] || "unknown"),
      status: to_string(saga_state[:state] || "active"),
      created_at: created_at,
      updated_at: now
    }

    # 既存のレコードを削除してから挿入する
    from(s in "sagas", where: s.id == ^uuid_binary)
    |> Repo.delete_all()

    case Repo.insert_all("sagas", [saga_record]) do
      {1, _} ->
        Logger.info("Saga #{saga_id} persisted successfully")
        {:ok, saga_id}

      error ->
        Logger.error("Failed to persist saga #{saga_id}: #{inspect(error)}")
        {:error, "Failed to persist saga"}
    end
  end

  @doc """
  SAGA の状態を取得する
  """
  def get_saga(saga_id) do
    uuid_binary = convert_uuid_to_binary(saga_id)
    query = from(s in "sagas", where: s.id == ^uuid_binary, select: s)

    case Repo.one(query) do
      nil ->
        {:error, :not_found}

      saga ->
        {:ok, decode_saga(saga)}
    end
  end

  @doc """
  未完了の SAGA を取得する
  """
  def get_incomplete_sagas do
    query =
      from(s in "sagas",
        where: s.status not in ["completed", "failed", "compensated"],
        select: s
      )

    sagas = Repo.all(query)
    Enum.map(sagas, &decode_saga/1)
  end

  @doc """
  アクティブな SAGA を取得する
  """
  def get_active_sagas do
    query =
      from(s in "sagas",
        where: s.status in ["started", "processing"],
        select: %{
          id: s.id,
          saga_type: s.saga_type,
          status: s.status,
          state: s.state,
          current_step: s.current_step,
          created_at: s.created_at,
          updated_at: s.updated_at
        }
      )

    sagas = Repo.all(query)
    {:ok, Enum.map(sagas, &decode_saga/1)}
  rescue
    e ->
      {:error, e}
  end

  @doc """
  SAGA を削除する
  """
  def delete_saga(saga_id) do
    uuid_binary = convert_uuid_to_binary(saga_id)
    query = from(s in "sagas", where: s.id == ^uuid_binary)

    case Repo.delete_all(query) do
      {1, _} -> :ok
      _ -> {:error, :not_found}
    end
  end

  # プライベート関数

  defp convert_to_naive_datetime(nil), do: nil

  defp convert_to_naive_datetime(%DateTime{} = datetime) do
    DateTime.to_naive(datetime)
    |> NaiveDateTime.truncate(:microsecond)
  end

  defp convert_to_naive_datetime(%NaiveDateTime{} = naive_datetime) do
    NaiveDateTime.truncate(naive_datetime, :microsecond)
  end

  defp convert_to_naive_datetime(_), do: nil

  defp convert_uuid_to_binary(saga_id) when is_binary(saga_id) do
    case Ecto.UUID.dump(saga_id) do
      {:ok, binary} -> binary
      # 既にバイナリ形式の場合はそのまま返す
      _ -> saga_id
    end
  end

  defp convert_uuid_to_binary(saga_id), do: saga_id

  defp decode_saga(saga_record) do
    state = Jason.decode!(saga_record.state, keys: :atoms)

    %{
      saga_id: saga_record.id,
      saga_type: saga_record.saga_type,
      state: state,
      current_step: String.to_atom(saga_record.current_step),
      status: String.to_atom(saga_record.status),
      created_at: saga_record.created_at,
      updated_at: saga_record.updated_at
    }
  end
end
