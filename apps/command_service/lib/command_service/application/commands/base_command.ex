defmodule CommandService.Application.Commands.BaseCommand do
  @moduledoc """
  すべてのコマンドの基底モジュール

  コマンドの共通的な振る舞いと構造を定義します
  """

  @callback validate(map()) :: {:ok, struct()} | {:error, String.t()}
  @callback command_type() :: String.t()

  defmacro __using__(_opts) do
    quote do
      @behaviour CommandService.Application.Commands.BaseCommand

      @doc """
      コマンドのメタデータを作成する
      """
      def create_metadata(user_id \\ nil, metadata \\ %{}) do
        %{
          command_id: UUID.uuid4(),
          command_type: command_type(),
          user_id: user_id,
          issued_at: DateTime.utc_now(),
          metadata: metadata
        }
      end

      # バリデーションヘルパー関数
      defp validate_required(nil, field), do: {:error, "#{field} is required"}
      defp validate_required("", field), do: {:error, "#{field} is required"}
      defp validate_required(value, _field), do: :ok

      defp validate_positive_integer(value, field) when is_integer(value) and value > 0, do: :ok

      defp validate_positive_integer(_, field),
        do: {:error, "#{field} must be a positive integer"}

      defp validate_positive_number(value, field) when is_number(value) and value > 0, do: :ok

      defp validate_positive_number(value, field) when is_binary(value) do
        case Float.parse(value) do
          {float_val, ""} when float_val > 0 -> :ok
          _ -> {:error, "#{field} must be a positive number"}
        end
      end

      defp validate_positive_number(value, field) do
        # Decimal型の処理
        if Code.ensure_loaded?(Decimal) and is_struct(value, Decimal) do
          if Decimal.compare(value, Decimal.new(0)) == :gt do
            :ok
          else
            {:error, "#{field} must be a positive number"}
          end
        else
          {:error, "#{field} must be a positive number"}
        end
      end

      # デフォルト実装を提供
      def command_type do
        raise "command_type/0 must be implemented by #{__MODULE__}"
      end

      defoverridable command_type: 0

      defimpl Jason.Encoder do
        def encode(command, opts) do
          command
          |> Map.from_struct()
          |> Map.reject(fn {_k, v} -> is_nil(v) end)
          |> Jason.Encode.map(opts)
        end
      end
    end
  end
end
