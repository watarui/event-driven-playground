defmodule Shared.Infrastructure.Idempotency.SagaIdempotencyBehaviour do
  @moduledoc """
  Saga の冪等性パラメータ抽出のビヘイビア
  
  各 Saga はこのビヘイビアを実装して、ステップごとの
  冪等性キー生成に必要なパラメータを定義する
  """
  
  @doc """
  指定されたステップの実行に必要なパラメータを抽出する
  
  冪等性キーの生成に使用されるため、同じ入力に対して
  常に同じ出力を返す必要がある
  """
  @callback extract_step_params(step_name :: atom(), saga_state :: map()) :: map()
  
  @doc """
  指定されたステップの補償に必要なパラメータを抽出する
  
  冪等性キーの生成に使用されるため、同じ入力に対して
  常に同じ出力を返す必要がある
  """
  @callback extract_compensation_params(step_name :: atom(), saga_state :: map()) :: map()
end