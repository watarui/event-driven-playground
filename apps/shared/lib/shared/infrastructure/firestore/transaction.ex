defmodule Shared.Infrastructure.Firestore.Transaction do
  @moduledoc """
  Firestore トランザクションの実装

  アトミックな読み書き操作を提供します。
  """

  alias Shared.Infrastructure.Firestore.Client
  alias GoogleApi.Firestore.V1.Api.Projects

  alias GoogleApi.Firestore.V1.Model.{
    BeginTransactionRequest,
    CommitRequest,
    RollbackRequest,
    Write,
    Document,
    Value
  }

  require Logger

  @max_retries 5
  @retry_delay 100

  @doc """
  トランザクション内で操作を実行する

  ## 例

      Transaction.run(fn tx ->
        {:ok, doc} = Transaction.get(tx, "users", "user123")
        updated_doc = Map.put(doc, "counter", doc["counter"] + 1)
        Transaction.set(tx, "users", "user123", updated_doc)
        {:ok, updated_doc}
      end)
  """
  def run(fun, opts \\ []) do
    retries = Keyword.get(opts, :retries, @max_retries)
    run_with_retry(fun, retries)
  end

  defp run_with_retry(fun, retries_left) when retries_left > 0 do
    with {:ok, conn} <- Client.get_connection(),
         project_id <- Client.get_project_id(:shared),
         database <- "projects/#{project_id}/databases/(default)",
         {:ok, %{transaction: transaction_id}} <- begin_transaction(conn, database) do
      # トランザクションコンテキストを作成
      tx_context = %{
        conn: conn,
        project_id: project_id,
        database: database,
        transaction_id: transaction_id,
        reads: [],
        writes: []
      }

      # トランザクション関数を実行
      case execute_transaction_function(fun, tx_context) do
        {:ok, result, final_context} ->
          # コミット
          case commit_transaction(conn, database, final_context) do
            {:ok, _} ->
              {:ok, result}

            {:error, :conflict} ->
              # リトライ
              Process.sleep(@retry_delay)
              run_with_retry(fun, retries_left - 1)

            error ->
              rollback_transaction(conn, database, transaction_id)
              error
          end

        {:error, _} = error ->
          rollback_transaction(conn, database, transaction_id)
          error
      end
    end
  end

  defp run_with_retry(_fun, 0) do
    {:error, :max_retries_exceeded}
  end

  @doc """
  トランザクション内でドキュメントを読み取る
  """
  def get(tx_context, collection, doc_id) do
    name = build_document_name(tx_context.project_id, collection, doc_id)

    case Projects.firestore_projects_databases_documents_get(
           tx_context.conn,
           name,
           transaction: tx_context.transaction_id
         ) do
      {:ok, document} ->
        # 読み取ったドキュメントを記録（競合検出用）
        updated_context = Map.update!(tx_context, :reads, &[document | &1])
        {:ok, parse_document(document), updated_context}

      {:error, 404} ->
        {:ok, nil, tx_context}

      error ->
        error
    end
  end

  @doc """
  トランザクション内でドキュメントを設定する
  """
  def set(tx_context, collection, doc_id, data) do
    write = %Write{
      update: build_document(tx_context.project_id, collection, doc_id, data)
    }

    updated_context = Map.update!(tx_context, :writes, &[write | &1])
    {:ok, updated_context}
  end

  @doc """
  トランザクション内でドキュメントを削除する
  """
  def delete(tx_context, collection, doc_id) do
    name = build_document_name(tx_context.project_id, collection, doc_id)

    write = %Write{
      delete: name
    }

    updated_context = Map.update!(tx_context, :writes, &[write | &1])
    {:ok, updated_context}
  end

  # Private functions

  defp begin_transaction(conn, database) do
    request = %BeginTransactionRequest{
      # デフォルトオプション（読み書き可能）
      options: %{}
    }

    Projects.firestore_projects_databases_documents_begin_transaction(
      conn,
      database,
      body: request
    )
  end

  defp commit_transaction(conn, database, tx_context) do
    request = %CommitRequest{
      transaction: tx_context.transaction_id,
      # 書き込み順序を保持
      writes: Enum.reverse(tx_context.writes)
    }

    case Projects.firestore_projects_databases_documents_commit(
           conn,
           database,
           body: request
         ) do
      {:ok, _result} ->
        {:ok, :committed}

      {:error, %{status: 409}} ->
        {:error, :conflict}

      error ->
        error
    end
  end

  defp rollback_transaction(conn, database, transaction_id) do
    request = %RollbackRequest{
      transaction: transaction_id
    }

    Projects.firestore_projects_databases_documents_rollback(
      conn,
      database,
      body: request
    )
  catch
    # ロールバックの失敗は無視
    _ -> :ok
  end

  defp execute_transaction_function(fun, tx_context) do
    try do
      result = fun.(tx_context)

      case result do
        {:ok, value, final_context} -> {:ok, value, final_context}
        {:ok, value} -> {:ok, value, tx_context}
        {:error, _} = error -> error
        value -> {:ok, value, tx_context}
      end
    rescue
      e ->
        Logger.error("Transaction function failed: #{inspect(e)}")
        {:error, e}
    end
  end

  defp build_document_name(project_id, collection, doc_id) do
    "projects/#{project_id}/databases/(default)/documents/#{collection}/#{doc_id}"
  end

  defp build_document(project_id, collection, doc_id, data) do
    %Document{
      name: build_document_name(project_id, collection, doc_id),
      fields: encode_fields(data)
    }
  end

  defp encode_fields(data) when is_map(data) do
    Map.new(data, fn {key, value} ->
      {to_string(key), encode_value(value)}
    end)
  end

  defp encode_value(value) when is_binary(value) do
    %Value{stringValue: value}
  end

  defp encode_value(value) when is_integer(value) do
    %Value{integerValue: to_string(value)}
  end

  defp encode_value(value) when is_float(value) do
    %Value{doubleValue: value}
  end

  defp encode_value(value) when is_boolean(value) do
    %Value{booleanValue: value}
  end

  defp encode_value(nil) do
    %Value{nullValue: "NULL_VALUE"}
  end

  defp encode_value(value) when is_map(value) do
    %Value{
      mapValue: %{fields: encode_fields(value)}
    }
  end

  defp encode_value(value) when is_list(value) do
    %Value{
      arrayValue: %{values: Enum.map(value, &encode_value/1)}
    }
  end

  defp encode_value(%DateTime{} = value) do
    %Value{timestampValue: DateTime.to_iso8601(value)}
  end

  defp encode_value(value) do
    %Value{stringValue: to_string(value)}
  end

  defp parse_document(%Document{fields: fields}) do
    fields
    |> Enum.map(fn {key, value} -> {key, parse_value(value)} end)
    |> Enum.into(%{})
  end

  defp parse_value(%Value{} = value) do
    cond do
      value.stringValue != nil -> value.stringValue
      value.integerValue != nil -> String.to_integer(value.integerValue)
      value.doubleValue != nil -> value.doubleValue
      value.booleanValue != nil -> value.booleanValue
      value.mapValue != nil -> parse_map_value(value.mapValue)
      value.arrayValue != nil -> Enum.map(value.arrayValue.values || [], &parse_value/1)
      value.nullValue != nil -> nil
      value.timestampValue != nil -> parse_timestamp(value.timestampValue)
      true -> nil
    end
  end

  defp parse_map_value(%{fields: fields}) do
    fields
    |> Enum.map(fn {k, v} -> {k, parse_value(v)} end)
    |> Enum.into(%{})
  end

  defp parse_timestamp(timestamp_string) do
    case DateTime.from_iso8601(timestamp_string) do
      {:ok, datetime, _} -> datetime
      _ -> timestamp_string
    end
  end
end
