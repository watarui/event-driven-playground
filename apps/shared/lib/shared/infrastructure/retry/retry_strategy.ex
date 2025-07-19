defmodule Shared.Infrastructure.Retry.RetryStrategy do
  @moduledoc """
  高度なリトライ戦略を提供するモジュール。
  エクスポネンシャルバックオフ、ジッター、最大リトライ回数などをサポート。
  """

  require Logger

  @type retry_options :: %{
          max_attempts: non_neg_integer(),
          base_delay: non_neg_integer(),
          max_delay: non_neg_integer(),
          jitter: boolean(),
          backoff_type: :exponential | :linear | :constant
        }

  @type retry_result :: {:ok, any()} | {:error, :max_attempts_exceeded, list()}

  @default_options %{
    max_attempts: 3,
    base_delay: 100,
    max_delay: 5_000,
    jitter: true,
    backoff_type: :exponential
  }

  @doc """
  リトライ可能な操作を実行する

  ## Options
    * `:max_attempts` - 最大試行回数（デフォルト: 3）
    * `:base_delay` - 基本遅延時間（ミリ秒、デフォルト: 100）
    * `:max_delay` - 最大遅延時間（ミリ秒、デフォルト: 5000）
    * `:jitter` - ジッターを追加するか（デフォルト: true）
    * `:backoff_type` - バックオフタイプ（:exponential | :linear | :constant、デフォルト: :exponential）

  ## Examples
      iex> RetryStrategy.execute(fn -> {:ok, "success"} end)
      {:ok, "success"}

      iex> RetryStrategy.execute(
      ...>   fn -> {:error, "temporary error"} end,
      ...>   max_attempts: 2
      ...> )
      {:error, :max_attempts_exceeded, [...]}
  """
  @spec execute((-> {:ok, any()} | {:error, any()}), map()) :: retry_result()
  def execute(operation, options \\ %{}) do
    options = Map.merge(@default_options, options)
    do_execute(operation, options, 1, [])
  end

  @doc """
  条件付きリトライを実行する

  特定のエラータイプのみリトライする場合に使用。

  ## Examples
      iex> RetryStrategy.execute_with_condition(
      ...>   fn -> {:error, :timeout} end,
      ...>   fn error -> error == :timeout end
      ...> )
  """
  @spec execute_with_condition(
          (-> {:ok, any()} | {:error, any()}),
          (any() -> boolean()),
          map()
        ) :: retry_result()
  def execute_with_condition(operation, should_retry?, options \\ %{}) do
    options = Map.merge(@default_options, options)
    do_execute_with_condition(operation, should_retry?, options, 1, [])
  end

  @doc """
  指定した回数に基づいて遅延時間を計算する

  ## Examples
      iex> RetryStrategy.calculate_delay(1, %{backoff_type: :exponential, base_delay: 100})
      200

      iex> RetryStrategy.calculate_delay(2, %{backoff_type: :linear, base_delay: 100})
      200
  """
  @spec calculate_delay(non_neg_integer(), map()) :: non_neg_integer()
  def calculate_delay(attempt, options) do
    base_delay = options.base_delay
    max_delay = options.max_delay

    delay =
      case options.backoff_type do
        :exponential ->
          round(base_delay * :math.pow(2, attempt - 1))

        :linear ->
          base_delay * attempt

        :constant ->
          base_delay
      end

    delay = min(delay, max_delay)

    if options.jitter do
      add_jitter(delay)
    else
      delay
    end
  end

  # Private functions

  defp do_execute(operation, options, attempt, errors) when attempt <= options.max_attempts do
    case operation.() do
      {:ok, _result} = success ->
        if attempt > 1 do
          Logger.info("Operation succeeded after #{attempt} attempts")
        end

        success

      {:error, error} = failure ->
        Logger.warning("Attempt #{attempt} failed: #{inspect(error)}")
        errors = [{attempt, error} | errors]

        if attempt < options.max_attempts do
          delay = calculate_delay(attempt, options)
          Logger.debug("Retrying after #{delay}ms...")
          Process.sleep(delay)
          do_execute(operation, options, attempt + 1, errors)
        else
          {:error, :max_attempts_exceeded, Enum.reverse(errors)}
        end

      other ->
        # 予期しない戻り値の場合はエラーとして扱う
        do_execute(fn -> {:error, {:unexpected_return, other}} end, options, attempt, errors)
    end
  end

  defp do_execute(_operation, _options, _attempt, errors) do
    {:error, :max_attempts_exceeded, Enum.reverse(errors)}
  end

  defp do_execute_with_condition(
         operation,
         should_retry?,
         options,
         attempt,
         errors
       )
       when attempt <= options.max_attempts do
    case operation.() do
      {:ok, _result} = success ->
        if attempt > 1 do
          Logger.info("Operation succeeded after #{attempt} attempts")
        end

        success

      {:error, error} ->
        Logger.warning("Attempt #{attempt} failed: #{inspect(error)}")
        errors = [{attempt, error} | errors]

        if attempt < options.max_attempts && should_retry?.(error) do
          delay = calculate_delay(attempt, options)
          Logger.debug("Retrying after #{delay}ms...")
          Process.sleep(delay)
          do_execute_with_condition(operation, should_retry?, options, attempt + 1, errors)
        else
          if !should_retry?.(error) do
            Logger.info("Error is not retryable: #{inspect(error)}")
          end

          {:error, error}
        end

      other ->
        # 予期しない戻り値の場合はエラーとして扱う
        do_execute_with_condition(
          fn -> {:error, {:unexpected_return, other}} end,
          should_retry?,
          options,
          attempt,
          errors
        )
    end
  end

  defp do_execute_with_condition(_operation, _should_retry?, _options, _attempt, errors) do
    {:error, :max_attempts_exceeded, Enum.reverse(errors)}
  end

  defp add_jitter(delay) do
    # 0から25%の範囲でランダムなジッターを追加
    jitter_range = round(delay * 0.25)
    jitter = :rand.uniform(jitter_range) - div(jitter_range, 2)
    max(1, delay + jitter)
  end
end
