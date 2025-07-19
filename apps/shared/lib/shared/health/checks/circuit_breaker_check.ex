defmodule Shared.Health.Checks.CircuitBreakerCheck do
  @moduledoc """
  サーキットブレーカーの状態チェック

  各サーキットブレーカーの状態を確認し、開いているブレーカーがある場合は警告します。
  """

  alias Shared.Infrastructure.Resilience.CircuitBreaker

  require Logger

  @doc """
  全サーキットブレーカーの状態を確認
  """
  def check do
    breakers = get_all_breakers()

    breaker_states =
      breakers
      |> Enum.map(fn breaker_name ->
        case CircuitBreaker.get_state(breaker_name) do
          {:ok, state} -> {breaker_name, state}
          {:error, _} -> {breaker_name, :unknown}
        end
      end)
      |> Enum.into(%{})

    open_breakers =
      breaker_states
      |> Enum.filter(fn {_, state} -> state == :open end)
      |> Enum.map(fn {name, _} -> name end)

    half_open_breakers =
      breaker_states
      |> Enum.filter(fn {_, state} -> state == :half_open end)
      |> Enum.map(fn {name, _} -> name end)

    details = %{
      total: length(breakers),
      states: breaker_states,
      open: open_breakers,
      half_open: half_open_breakers
    }

    cond do
      not Enum.empty?(open_breakers) ->
        {:degraded, "Circuit breakers open: #{inspect(open_breakers)}", details}

      not Enum.empty?(half_open_breakers) ->
        {:degraded, "Circuit breakers half-open: #{inspect(half_open_breakers)}", details}

      true ->
        {:ok, details}
    end
  end

  defp get_all_breakers do
    # Registry から全てのサーキットブレーカーを取得
    Registry.select(:circuit_breaker_registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
    |> Enum.uniq()
  rescue
    _ -> []
  end
end
