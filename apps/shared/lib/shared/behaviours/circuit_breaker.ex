defmodule Shared.Behaviours.CircuitBreaker do
  @moduledoc """
  サーキットブレーカーパターンのインターフェース定義

  障害の連鎖を防ぎ、システムの復旧時間を短縮するための
  パターンを定義します。
  """

  alias Shared.Types

  @type state :: :closed | :open | :half_open
  @type name :: atom()
  @type fun :: (-> any())
  @type result :: Types.result()
  @type stats :: %{
          total_calls: non_neg_integer(),
          total_failures: non_neg_integer(),
          total_successes: non_neg_integer(),
          circuit_opens: non_neg_integer(),
          current_state: state(),
          failure_count: non_neg_integer(),
          success_count: non_neg_integer(),
          last_opened_at: DateTime.t() | nil
        }

  @type config :: %{
          failure_threshold: non_neg_integer(),
          success_threshold: non_neg_integer(),
          timeout: non_neg_integer(),
          reset_timeout: non_neg_integer()
        }

  @doc """
  サーキットブレーカーを開始する
  """
  @callback start_link(keyword()) :: GenServer.on_start()

  @doc """
  サーキットブレーカーを通じて関数を実行する

  サーキットが開いている場合は即座に失敗を返します。
  """
  @callback call(name(), fun()) ::
              {:ok, any()} | {:error, :circuit_open | term()}

  @doc """
  非同期で関数を実行する

  結果は別途取得する必要があります。
  """
  @callback call_async(name(), fun()) ::
              {:ok, reference()} | {:error, :circuit_open}

  @doc """
  現在の状態を取得する
  """
  @callback get_state(name()) :: {:ok, state()} | {:error, :not_found}

  @doc """
  統計情報を取得する
  """
  @callback get_stats(name()) :: {:ok, stats()} | {:error, :not_found}

  @doc """
  サーキットブレーカーを手動でリセットする

  管理操作として使用。通常は自動的に状態遷移します。
  """
  @callback reset(name()) :: :ok | {:error, :not_found}

  @doc """
  サーキットブレーカーを手動で開く

  メンテナンスや緊急時に使用。
  """
  @callback trip(name()) :: :ok | {:error, :not_found}

  @doc """
  設定を更新する

  実行時に設定を変更できます。
  """
  @callback update_config(name(), config()) :: :ok | {:error, term()}

  @doc """
  ヘルスチェック
  """
  @callback health_check(name()) :: :ok | {:error, term()}

  @optional_callbacks [
    call_async: 2,
    trip: 1,
    update_config: 2,
    health_check: 1
  ]
end
