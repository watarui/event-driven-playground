defmodule Shared.Infrastructure.Retry.RetryPolicy do
  @moduledoc """
  エラータイプに基づいてリトライポリシーを定義するモジュール。
  異なるエラータイプに対して適切なリトライ戦略を選択する。
  """

  alias Shared.Infrastructure.Retry.RetryStrategy

  @type error_type :: atom() | {atom(), any()}
  @type policy :: %{
          retryable: boolean(),
          options: map()
        }

  # デフォルトのエラータイプ別ポリシー
  @default_policies %{
    # ネットワーク関連のエラー
    :timeout => %{
      retryable: true,
      options: %{
        max_attempts: 5,
        base_delay: 200,
        max_delay: 10_000,
        backoff_type: :exponential
      }
    },
    :connection_error => %{
      retryable: true,
      options: %{
        max_attempts: 3,
        base_delay: 500,
        max_delay: 5_000,
        backoff_type: :exponential
      }
    },
    :service_unavailable => %{
      retryable: true,
      options: %{
        max_attempts: 4,
        base_delay: 1_000,
        max_delay: 30_000,
        backoff_type: :exponential
      }
    },

    # データベース関連のエラー
    :database_timeout => %{
      retryable: true,
      options: %{
        max_attempts: 3,
        base_delay: 100,
        max_delay: 2_000,
        backoff_type: :linear
      }
    },
    :deadlock => %{
      retryable: true,
      options: %{
        max_attempts: 3,
        base_delay: 50,
        max_delay: 500,
        jitter: true,
        backoff_type: :exponential
      }
    },

    # イベントストア関連のエラー
    :concurrent_modification => %{
      retryable: true,
      options: %{
        max_attempts: 5,
        base_delay: 50,
        max_delay: 1_000,
        jitter: true,
        backoff_type: :exponential
      }
    },
    :event_store_unavailable => %{
      retryable: true,
      options: %{
        max_attempts: 3,
        base_delay: 1_000,
        max_delay: 10_000,
        backoff_type: :exponential
      }
    },

    # リトライ不可能なエラー
    :validation_error => %{
      retryable: false,
      options: %{}
    },
    :unauthorized => %{
      retryable: false,
      options: %{}
    },
    :not_found => %{
      retryable: false,
      options: %{}
    },
    :business_rule_violation => %{
      retryable: false,
      options: %{}
    }
  }

  @doc """
  エラータイプに基づいてポリシーを取得する

  ## Examples
      iex> RetryPolicy.get_policy(:timeout)
      %{retryable: true, options: %{...}}

      iex> RetryPolicy.get_policy(:validation_error)
      %{retryable: false, options: %{}}
  """
  @spec get_policy(error_type()) :: policy()
  def get_policy(error_type) do
    @default_policies[error_type] || %{retryable: false, options: %{}}
  end

  @doc """
  エラーがリトライ可能かどうかを判定する

  ## Examples
      iex> RetryPolicy.retryable?(:timeout)
      true

      iex> RetryPolicy.retryable?(:validation_error)
      false
  """
  @spec retryable?(error_type()) :: boolean()
  def retryable?(error_type) do
    policy = get_policy(error_type)
    policy.retryable
  end

  @doc """
  ポリシーに基づいて操作を実行する

  エラータイプを分析し、適切なリトライ戦略を適用する。

  ## Examples
      iex> RetryPolicy.execute_with_policy(fn ->
      ...>   case do_something() do
      ...>     {:ok, result} -> {:ok, result}
      ...>     {:error, :timeout} -> {:error, :timeout}
      ...>   end
      ...> end)
  """
  @spec execute_with_policy((-> {:ok, any()} | {:error, error_type()})) ::
          {:ok, any()} | {:error, any()}
  def execute_with_policy(operation) do
    RetryStrategy.execute_with_condition(
      operation,
      fn error ->
        error_type = extract_error_type(error)
        retryable?(error_type)
      end,
      determine_retry_options(operation)
    )
  end

  @doc """
  カスタムポリシーを適用して操作を実行する

  ## Examples
      iex> custom_policies = %{
      ...>   my_error: %{retryable: true, options: %{max_attempts: 2}}
      ...> }
      iex> RetryPolicy.execute_with_custom_policy(
      ...>   fn -> {:error, :my_error} end,
      ...>   custom_policies
      ...> )
  """
  @spec execute_with_custom_policy(
          (-> {:ok, any()} | {:error, error_type()}),
          map()
        ) :: {:ok, any()} | {:error, any()}
  def execute_with_custom_policy(operation, custom_policies) do
    policies = Map.merge(@default_policies, custom_policies)

    RetryStrategy.execute_with_condition(
      operation,
      fn error ->
        error_type = extract_error_type(error)
        policy = policies[error_type] || %{retryable: false}
        policy.retryable
      end,
      determine_retry_options_with_policies(operation, policies)
    )
  end

  @doc """
  複数のポリシーを組み合わせる

  ## Examples
      iex> RetryPolicy.merge_policies(
      ...>   %{timeout: %{retryable: true, options: %{max_attempts: 5}}},
      ...>   %{timeout: %{retryable: true, options: %{max_attempts: 3}}}
      ...> )
      %{timeout: %{retryable: true, options: %{max_attempts: 3}}}
  """
  @spec merge_policies(map(), map()) :: map()
  def merge_policies(base_policies, override_policies) do
    Map.merge(base_policies, override_policies, fn _key, base, override ->
      %{
        retryable: override[:retryable] || base[:retryable],
        options: Map.merge(base[:options] || %{}, override[:options] || %{})
      }
    end)
  end

  # Private functions

  defp extract_error_type(error) when is_atom(error), do: error
  defp extract_error_type({error_type, _details}) when is_atom(error_type), do: error_type
  defp extract_error_type(_), do: :unknown_error

  defp determine_retry_options(operation) do
    # 最初の実行を試みてエラータイプを判定
    case operation.() do
      {:ok, _} ->
        %{}

      {:error, error} ->
        error_type = extract_error_type(error)
        policy = get_policy(error_type)
        policy.options || %{}
    end
  end

  defp determine_retry_options_with_policies(operation, policies) do
    # 最初の実行を試みてエラータイプを判定
    case operation.() do
      {:ok, _} ->
        %{}

      {:error, error} ->
        error_type = extract_error_type(error)
        policy = policies[error_type] || %{options: %{}}
        policy.options || %{}
    end
  end
end
