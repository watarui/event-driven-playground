defmodule Shared.Types do
  @moduledoc """
  共通で使用される型定義

  プロジェクト全体で使用される型を一元管理し、
  型安全性を向上させる。
  """

  # 基本的な ID 型
  @type command_id :: String.t()
  @type aggregate_id :: String.t()
  @type event_id :: String.t()
  @type saga_id :: String.t()
  @type user_id :: String.t()
  @type entity_id :: String.t()

  # イベント関連の型
  @type event_type :: atom()
  @type event_version :: non_neg_integer()
  @type event_data :: map()
  @type event_metadata :: %{optional(atom()) => any()}

  # 時刻関連の型
  @type timestamp :: DateTime.t()
  @type naive_timestamp :: NaiveDateTime.t()

  # 結果型
  @type result(success) :: {:ok, success} | {:error, term()}
  @type result :: result(any())

  # コマンド・クエリ関連
  @type command :: struct()
  @type query :: struct()
  @type event :: struct()

  # 認証・認可関連
  @type role :: :admin | :writer | :reader
  @type permission :: :read | :write | :delete | :admin
  @type user_context :: %{
          required(:id) => user_id(),
          required(:email) => String.t(),
          required(:role) => role(),
          optional(atom()) => any()
        }

  # ページネーション
  @type page_info :: %{
          required(:page) => non_neg_integer(),
          required(:page_size) => non_neg_integer(),
          required(:total_count) => non_neg_integer(),
          required(:total_pages) => non_neg_integer()
        }

  # エラー型
  @type error_reason :: atom() | String.t() | {atom(), any()}
  @type validation_error :: {atom(), String.t()}
  @type validation_errors :: [validation_error()]

  # Saga 関連
  @type saga_state :: %{
          required(:id) => saga_id(),
          required(:saga_type) => module(),
          required(:status) => saga_status(),
          required(:current_step) => atom() | nil,
          required(:data) => map(),
          optional(atom()) => any()
        }
  @type saga_status :: :pending | :running | :compensating | :completed | :failed | :timeout
  @type saga_step_result :: {:ok, [command()]} | {:error, error_reason()}

  # GraphQL 関連
  @type resolution :: %{
          required(:value) => any(),
          required(:context) => map(),
          optional(atom()) => any()
        }

  # 設定関連
  @type config_key :: atom() | [atom()]
  @type config_value :: any()
  @type config :: %{optional(atom()) => config_value()}
end
