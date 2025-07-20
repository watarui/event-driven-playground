defmodule Shared.Infrastructure.Idempotency.IdempotentSaga do
  @moduledoc """
  Sagaステップにべき等性を追加するヘルパーモジュール

  各Sagaステップの実行結果をキャッシュし、
  同じステップが再実行された場合はキャッシュした結果を返す。
  """

  alias Shared.Infrastructure.Idempotency.{IdempotencyKey, IdempotencyStore}
  require Logger

  @doc """
  Sagaステップをべき等に実行する

  ## Parameters
  - `saga_id` - SagaのID
  - `step_name` - ステップ名
  - `saga_state` - Sagaの状態
  - `operation` - 実行する操作（0引数の関数）
  - `opts` - オプション

  ## Examples
      IdempotentSaga.execute_step(saga_id, :reserve_inventory, saga_state, fn ->
        # ステップの処理
        {:ok, commands}
      end)
  """
  @spec execute_step(String.t(), atom(), map(), function(), keyword()) ::
          {:ok, any()} | {:error, any()}
  def execute_step(saga_id, step_name, saga_state, operation, opts \\ []) do
    # べき等性キーを生成
    key = generate_step_key(saga_id, step_name, saga_state)

    # TTLはSagaステップ用の値を使用
    ttl = Keyword.get(opts, :ttl, IdempotencyKey.ttl_seconds("saga_step"))

    # べき等に実行
    result = IdempotencyStore.execute(key, operation, ttl: ttl)

    case result do
      {:ok, value} ->
        Logger.debug("Saga step executed idempotently: #{saga_id}/#{step_name}")
        {:ok, value}

      {:error, reason} = error ->
        Logger.error("Saga step execution failed: #{saga_id}/#{step_name} - #{inspect(reason)}")
        error
    end
  end

  @doc """
  補償ステップをべき等に実行する

  補償は失敗してもリトライされることがあるため、
  べき等性が特に重要。
  """
  @spec compensate_step(String.t(), atom(), map(), function(), keyword()) ::
          {:ok, any()} | {:error, any()}
  def compensate_step(saga_id, step_name, saga_state, operation, opts \\ []) do
    # 補償用のキーを生成（通常のステップとは別）
    key = generate_compensation_key(saga_id, step_name, saga_state)

    # 補償は長めのTTLを設定
    # デフォルト4時間
    ttl = Keyword.get(opts, :ttl, 14_400)

    # べき等に実行
    result = IdempotencyStore.execute(key, operation, ttl: ttl)

    case result do
      {:ok, value} ->
        Logger.info("Saga compensation executed idempotently: #{saga_id}/#{step_name}")
        {:ok, value}

      {:error, reason} = error ->
        Logger.error("Saga compensation failed: #{saga_id}/#{step_name} - #{inspect(reason)}")
        error
    end
  end

  @doc """
  Sagaのすべてのべき等性キーをクリアする

  Sagaが完了または失敗した場合に呼び出す。
  """
  @spec clear_saga_keys(String.t()) :: :ok
  def clear_saga_keys(saga_id) do
    # 実装の簡略化のため、個別のキー削除は行わない
    # 実際の実装では、Sagaに関連するすべてのキーを削除する
    Logger.debug("Clearing idempotency keys for saga: #{saga_id}")
    :ok
  end

  # Private functions

  defp generate_step_key(saga_id, step_name, saga_state) do
    # ステップの入力パラメータをハッシュ化
    step_params = extract_step_params(step_name, saga_state)

    IdempotencyKey.generate(
      "saga_step",
      saga_id,
      to_string(step_name),
      step_params
    )
  end

  defp generate_compensation_key(saga_id, step_name, saga_state) do
    # 補償の入力パラメータをハッシュ化
    compensation_params = extract_compensation_params(step_name, saga_state)

    IdempotencyKey.generate(
      "saga_compensation",
      saga_id,
      to_string(step_name),
      compensation_params
    )
  end

  defp extract_step_params(step_name, saga_state) do
    # Saga モジュールが冪等性ビヘイビアを実装している場合は使用
    saga_module = Map.get(saga_state, :saga_type)

    if saga_module && function_exported?(saga_module, :extract_step_params, 2) do
      saga_module.extract_step_params(step_name, saga_state)
    else
      # デフォルトの実装
      extract_default_step_params(step_name, saga_state)
    end
  end

  defp extract_compensation_params(step_name, saga_state) do
    # Saga モジュールが冪等性ビヘイビアを実装している場合は使用
    saga_module = Map.get(saga_state, :saga_type)

    if saga_module && function_exported?(saga_module, :extract_compensation_params, 2) do
      saga_module.extract_compensation_params(step_name, saga_state)
    else
      # デフォルトの実装
      extract_default_compensation_params(step_name, saga_state)
    end
  end

  defp extract_default_step_params(step_name, saga_state) do
    # 後方互換性のためのデフォルト実装
    case step_name do
      :reserve_inventory ->
        %{
          items: Map.get(saga_state, :items, []),
          order_id: Map.get(saga_state, :order_id)
        }

      :process_payment ->
        %{
          amount: Map.get(saga_state, :total_amount),
          user_id: Map.get(saga_state, :user_id)
        }

      :arrange_shipping ->
        %{
          order_id: Map.get(saga_state, :order_id),
          shipping_address: Map.get(saga_state, :shipping_address)
        }

      _ ->
        %{
          order_id: Map.get(saga_state, :order_id),
          current_step: Map.get(saga_state, :current_step)
        }
    end
  end

  defp extract_default_compensation_params(step_name, saga_state) do
    # 後方互換性のためのデフォルト実装
    case step_name do
      :reserve_inventory ->
        %{
          reservation_ids: Map.get(saga_state, :reservation_ids, [])
        }

      :process_payment ->
        %{
          transaction_id: Map.get(saga_state, :payment_transaction_id)
        }

      :arrange_shipping ->
        %{
          tracking_id: Map.get(saga_state, :shipping_tracking_id)
        }

      _ ->
        %{
          order_id: Map.get(saga_state, :order_id),
          failed_step: Map.get(saga_state, :failed_step)
        }
    end
  end
end
