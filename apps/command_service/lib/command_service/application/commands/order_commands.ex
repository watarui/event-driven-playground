defmodule CommandService.Application.Commands.OrderCommands do
  @moduledoc """
  注文関連のコマンド定義（プロトコルベース）
  """

  alias CommandService.Application.Handlers.OrderCommandHandler
  alias Shared.Domain.ValueObjects.{EntityId, Money}

  defmodule CreateOrder do
    @moduledoc """
    注文作成コマンド
    """
    use Shared.CQRS.Command.Helpers,
      handler: OrderCommandHandler,
      aggregate_type: :order

    @enforce_keys [:user_id, :items]
    defstruct [:user_id, :items, :shipping_address, :metadata]

    @type t :: %__MODULE__{
            user_id: EntityId.t(),
            items: [map()],
            shipping_address: map() | nil,
            metadata: map() | nil
          }

    @doc """
    新しいCreateOrderコマンドを作成
    """
    @spec new(map()) :: {:ok, t()} | {:error, term()}
    def new(params) do
      with {:ok, user_id} <- validate_user_id(params[:user_id] || params["user_id"]),
           {:ok, items} <- validate_items_params(params[:items] || params["items"]) do
        command = %__MODULE__{
          user_id: user_id,
          items: items,
          shipping_address: params[:shipping_address] || params["shipping_address"],
          metadata: params[:metadata] || params["metadata"] || %{}
        }

        case validate(command) do
          :ok -> {:ok, command}
          error -> error
        end
      else
        {:error, "Invalid UUID"} ->
          {:error, Shared.Domain.Errors.BusinessRuleError,
           %{rule: "order_creation", context: %{reason: "Invalid UUID"}}}

        {:error, reason} ->
          {:error, Shared.Domain.Errors.BusinessRuleError,
           %{rule: "order_creation", context: %{reason: inspect(reason)}}}
      end
    end

    defp validate_user_id(nil), do: {:error, :user_id_required}

    defp validate_user_id(user_id) when is_binary(user_id) do
      case EntityId.from_string(user_id) do
        {:ok, id} -> {:ok, id}
        {:error, reason} -> {:error, reason}
      end
    end

    defp validate_user_id(%EntityId{} = id), do: {:ok, id}
    defp validate_user_id(_), do: {:error, :invalid_user_id}

    defp validate_items_params(nil), do: {:error, :items_required}
    defp validate_items_params([]), do: {:error, :items_required}

    defp validate_items_params(items) when is_list(items) do
      {:ok, Enum.map(items, &normalize_item/1)}
    end

    defp validate_items_params(_), do: {:error, :invalid_items}

    defp normalize_item(item) when is_map(item) do
      %{
        product_id: item[:product_id] || item["product_id"],
        product_name: item[:product_name] || item["product_name"],
        quantity: item[:quantity] || item["quantity"],
        unit_price: normalize_price(item[:unit_price] || item["unit_price"])
      }
    end

    defp normalize_price(price) when is_binary(price) do
      case Decimal.parse(price) do
        {decimal, _} -> decimal
        :error -> Decimal.new(0)
      end
    end

    defp normalize_price(%Decimal{} = price), do: price
    defp normalize_price(price) when is_float(price), do: Decimal.from_float(price)
    defp normalize_price(price) when is_integer(price), do: Decimal.new(price)
    defp normalize_price(_), do: Decimal.new(0)

    @spec validate(t()) :: :ok | {:error, map()}
    def validate(%__MODULE__{} = command) do
      errors = %{}

      errors =
        if command.user_id == nil || command.user_id == "" do
          Map.put(errors, :user_id, "is required")
        else
          errors
        end

      errors =
        case validate_items(command.items) do
          :ok -> errors
          {:error, item_errors} -> Map.put(errors, :items, item_errors)
        end

      if map_size(errors) == 0 do
        :ok
      else
        {:error, errors}
      end
    end

    defp validate_items(nil), do: {:error, "is required"}
    defp validate_items([]), do: {:error, "cannot be empty"}

    defp validate_items(items) when is_list(items) do
      item_errors =
        items
        |> Enum.with_index()
        |> Enum.reduce(%{}, fn {item, index}, acc ->
          case validate_item(item) do
            :ok -> acc
            {:error, error} -> Map.put(acc, index, error)
          end
        end)

      if map_size(item_errors) == 0 do
        :ok
      else
        {:error, item_errors}
      end
    end

    defp validate_items(_), do: {:error, "must be a list"}

    defp validate_item(item) do
      cond do
        not is_map(item) ->
          {:error, "must be a map"}

        not Map.has_key?(item, :product_id) ->
          {:error, "product_id is required"}

        not Map.has_key?(item, :quantity) ->
          {:error, "quantity is required"}

        not is_integer(item.quantity) || item.quantity <= 0 ->
          {:error, "quantity must be a positive integer"}

        true ->
          :ok
      end
    end
  end

  defmodule ConfirmOrder do
    @moduledoc """
    注文確定コマンド
    """
    use Shared.CQRS.Command.Helpers,
      handler: OrderCommandHandler,
      aggregate_type: :order

    @enforce_keys [:order_id]
    defstruct [:order_id, :metadata]

    @type t :: %__MODULE__{
            order_id: EntityId.t(),
            metadata: map() | nil
          }

    def validate(%__MODULE__{order_id: nil}), do: {:error, %{order_id: "is required"}}
    def validate(%__MODULE__{}), do: :ok
  end

  defmodule CancelOrder do
    @moduledoc """
    注文キャンセルコマンド
    """
    use Shared.CQRS.Command.Helpers,
      handler: OrderCommandHandler,
      aggregate_type: :order

    @enforce_keys [:order_id, :reason]
    defstruct [:order_id, :reason, :metadata]

    @type t :: %__MODULE__{
            order_id: EntityId.t(),
            reason: String.t(),
            metadata: map() | nil
          }

    def validate(%__MODULE__{} = command) do
      errors = %{}

      errors =
        if command.order_id == nil do
          Map.put(errors, :order_id, "is required")
        else
          errors
        end

      errors =
        if command.reason == nil || command.reason == "" do
          Map.put(errors, :reason, "is required")
        else
          errors
        end

      if map_size(errors) == 0 do
        :ok
      else
        {:error, errors}
      end
    end
  end

  # Saga用コマンド

  defmodule ReserveInventory do
    @moduledoc """
    在庫予約コマンド（Saga用）
    """
    use Shared.CQRS.Command.Helpers,
      handler: OrderCommandHandler,
      aggregate_type: :inventory

    @enforce_keys [:order_id, :items]
    defstruct [:order_id, :items, :saga_id, :metadata]

    @type t :: %__MODULE__{
            order_id: String.t(),
            items: [map()],
            saga_id: String.t() | nil,
            metadata: map() | nil
          }

    def validate(%__MODULE__{order_id: nil}), do: {:error, %{order_id: "is required"}}
    def validate(%__MODULE__{items: nil}), do: {:error, %{items: "is required"}}
    def validate(%__MODULE__{items: []}), do: {:error, %{items: "cannot be empty"}}
    def validate(%__MODULE__{}), do: :ok
  end

  defmodule ProcessPayment do
    @moduledoc """
    支払い処理コマンド（Saga用）
    """
    use Shared.CQRS.Command.Helpers,
      handler: OrderCommandHandler,
      aggregate_type: :payment

    @enforce_keys [:order_id, :user_id, :amount]
    defstruct [:order_id, :user_id, :amount, :saga_id, :metadata]

    @type t :: %__MODULE__{
            order_id: String.t(),
            user_id: String.t(),
            amount: Money.t() | number(),
            saga_id: String.t() | nil,
            metadata: map() | nil
          }

    def validate(%__MODULE__{} = command) do
      cond do
        command.order_id == nil ->
          {:error, %{order_id: "is required"}}

        command.user_id == nil ->
          {:error, %{user_id: "is required"}}

        command.amount == nil ->
          {:error, %{amount: "is required"}}

        is_number(command.amount) && command.amount <= 0 ->
          {:error, %{amount: "must be positive"}}

        true ->
          :ok
      end
    end
  end

  defmodule ArrangeShipping do
    @moduledoc """
    配送手配コマンド（Saga用）
    """
    use Shared.CQRS.Command.Helpers,
      handler: OrderCommandHandler,
      aggregate_type: :shipping

    @enforce_keys [:order_id, :user_id, :shipping_address, :items]
    defstruct [:order_id, :user_id, :shipping_address, :items, :saga_id, :metadata]

    @type t :: %__MODULE__{
            order_id: String.t(),
            user_id: String.t(),
            shipping_address: map(),
            items: [map()],
            saga_id: String.t() | nil,
            metadata: map() | nil
          }

    def validate(%__MODULE__{} = command) do
      cond do
        command.order_id == nil -> {:error, %{order_id: "is required"}}
        command.user_id == nil -> {:error, %{user_id: "is required"}}
        command.shipping_address == nil -> {:error, %{shipping_address: "is required"}}
        command.items == nil || command.items == [] -> {:error, %{items: "is required"}}
        true -> :ok
      end
    end
  end

  # 補償用コマンド

  defmodule ReleaseInventory do
    @moduledoc """
    在庫解放コマンド（補償）
    """
    use Shared.CQRS.Command.Helpers,
      handler: OrderCommandHandler,
      aggregate_type: :inventory

    @enforce_keys [:order_id, :items]
    defstruct [:order_id, :items, :saga_id, :metadata]

    @type t :: %__MODULE__{
            order_id: String.t(),
            items: [map()],
            saga_id: String.t() | nil,
            metadata: map() | nil
          }

    def validate(%__MODULE__{order_id: nil}), do: {:error, %{order_id: "is required"}}
    def validate(%__MODULE__{items: nil}), do: {:error, %{items: "is required"}}
    def validate(%__MODULE__{}), do: :ok
  end

  defmodule RefundPayment do
    @moduledoc """
    支払い返金コマンド（補償）
    """
    use Shared.CQRS.Command.Helpers,
      handler: OrderCommandHandler,
      aggregate_type: :payment

    @enforce_keys [:order_id, :transaction_id, :amount]
    defstruct [:order_id, :transaction_id, :amount, :saga_id, :metadata]

    @type t :: %__MODULE__{
            order_id: String.t(),
            transaction_id: String.t(),
            amount: Money.t() | number(),
            saga_id: String.t() | nil,
            metadata: map() | nil
          }

    def validate(%__MODULE__{} = command) do
      cond do
        command.order_id == nil -> {:error, %{order_id: "is required"}}
        command.transaction_id == nil -> {:error, %{transaction_id: "is required"}}
        command.amount == nil -> {:error, %{amount: "is required"}}
        true -> :ok
      end
    end
  end

  defmodule CancelShipping do
    @moduledoc """
    配送キャンセルコマンド（補償）
    """
    use Shared.CQRS.Command.Helpers,
      handler: OrderCommandHandler,
      aggregate_type: :shipping

    @enforce_keys [:order_id, :tracking_id]
    defstruct [:order_id, :tracking_id, :saga_id, :metadata]

    @type t :: %__MODULE__{
            order_id: String.t(),
            tracking_id: String.t(),
            saga_id: String.t() | nil,
            metadata: map() | nil
          }

    def validate(%__MODULE__{order_id: nil}), do: {:error, %{order_id: "is required"}}
    def validate(%__MODULE__{tracking_id: nil}), do: {:error, %{tracking_id: "is required"}}
    def validate(%__MODULE__{}), do: :ok
  end
end
