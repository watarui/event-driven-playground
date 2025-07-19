defmodule CommandService.Domain.Aggregates.OrderAggregate do
  @moduledoc """
  注文アグリゲート

  注文の作成、確定、キャンセルに関するビジネスロジックを管理します
  """

  use Shared.Domain.Aggregate.Base

  alias Shared.Domain.ValueObjects.{EntityId, Money}

  alias Shared.Domain.Events.OrderEvents.{
    OrderCancelled,
    OrderConfirmed,
    OrderCreated,
    OrderItemReserved,
    OrderPaymentProcessed
  }

  @enforce_keys [:id]
  defstruct [
    :id,
    :user_id,
    :items,
    :total_amount,
    :status,
    :saga_id,
    :version,
    :created_at,
    :updated_at,
    :cancelled_at,
    :confirmed_at,
    uncommitted_events: []
  ]

  @type t :: %__MODULE__{
          id: EntityId.t(),
          user_id: EntityId.t() | nil,
          items: list(map()) | nil,
          total_amount: Money.t() | nil,
          status: atom() | nil,
          saga_id: EntityId.t() | nil,
          version: integer(),
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          cancelled_at: DateTime.t() | nil,
          confirmed_at: DateTime.t() | nil,
          uncommitted_events: list()
        }

  @impl true
  def new do
    %__MODULE__{
      id: EntityId.generate(),
      version: 0,
      status: :pending,
      uncommitted_events: []
    }
  end

  @doc """
  注文を作成する
  """
  @spec create(EntityId.t() | String.t(), list(map())) :: {:ok, t()} | {:error, String.t()}
  def create(user_id, items) do
    with {:ok, user_entity_id} <- ensure_entity_id(user_id),
         {:ok, validated_items} <- validate_items(items),
         {:ok, total} <- calculate_total(validated_items) do
      aggregate = new()

      event =
        OrderCreated.new(%{
          id: aggregate.id,
          user_id: user_entity_id,
          items: validated_items,
          total_amount: total,
          saga_id: EntityId.generate(),
          created_at: DateTime.utc_now()
        })

      {:ok, apply_and_record_event(aggregate, event)}
    end
  end

  @doc """
  在庫を予約済みとして記録する
  """
  @spec reserve_item(t(), String.t(), integer()) :: {:ok, t()} | {:error, String.t()}
  def reserve_item(%__MODULE__{status: :cancelled} = _aggregate, _product_id, _quantity) do
    {:error, "Cannot reserve items for cancelled order"}
  end

  def reserve_item(%__MODULE__{} = aggregate, product_id, quantity) do
    with {:ok, prod_id} <- EntityId.from_string(product_id) do
      event =
        OrderItemReserved.new(%{
          order_id: aggregate.id,
          product_id: prod_id,
          quantity: quantity,
          reserved_at: DateTime.utc_now()
        })

      {:ok, apply_and_record_event(aggregate, event)}
    end
  end

  @doc """
  支払い処理済みとして記録する
  """
  @spec process_payment(t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def process_payment(%__MODULE__{status: :cancelled} = _aggregate, _payment_id) do
    {:error, "Cannot process payment for cancelled order"}
  end

  def process_payment(%__MODULE__{} = aggregate, payment_id) do
    event =
      OrderPaymentProcessed.new(%{
        order_id: aggregate.id,
        amount: aggregate.total_amount,
        payment_id: payment_id,
        processed_at: DateTime.utc_now()
      })

    {:ok, apply_and_record_event(aggregate, event)}
  end

  @doc """
  注文を確定する
  """
  @spec confirm(t()) :: {:ok, t()} | {:error, String.t()}
  def confirm(%__MODULE__{status: :cancelled} = _aggregate) do
    {:error, "Cannot confirm cancelled order"}
  end

  def confirm(%__MODULE__{status: :confirmed} = _aggregate) do
    {:error, "Order already confirmed"}
  end

  def confirm(%__MODULE__{} = aggregate) do
    event =
      OrderConfirmed.new(%{
        id: aggregate.id,
        confirmed_at: DateTime.utc_now()
      })

    {:ok, apply_and_record_event(aggregate, event)}
  end

  @doc """
  注文をキャンセルする
  """
  @spec cancel(t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def cancel(%__MODULE__{status: :cancelled} = _aggregate, _reason) do
    {:error, "Order already cancelled"}
  end

  def cancel(%__MODULE__{status: :confirmed} = _aggregate, _reason) do
    {:error, "Cannot cancel confirmed order"}
  end

  def cancel(%__MODULE__{} = aggregate, reason) do
    event =
      OrderCancelled.new(%{
        id: aggregate.id,
        reason: reason,
        cancelled_at: DateTime.utc_now()
      })

    {:ok, apply_and_record_event(aggregate, event)}
  end

  @impl true
  def apply_event(aggregate, %OrderCreated{} = event) do
    %{
      aggregate
      | id: event.id,
        user_id: event.user_id,
        items: event.items,
        total_amount: event.total_amount,
        saga_id: event.saga_id,
        status: :pending,
        created_at: event.created_at,
        updated_at: event.created_at
    }
  end

  def apply_event(aggregate, %OrderItemReserved{} = _event) do
    %{aggregate | updated_at: DateTime.utc_now()}
  end

  def apply_event(aggregate, %OrderPaymentProcessed{} = _event) do
    %{aggregate | status: :payment_processed, updated_at: DateTime.utc_now()}
  end

  def apply_event(aggregate, %OrderConfirmed{} = event) do
    %{
      aggregate
      | status: :confirmed,
        confirmed_at: event.confirmed_at,
        updated_at: event.confirmed_at
    }
  end

  def apply_event(aggregate, %OrderCancelled{} = event) do
    %{
      aggregate
      | status: :cancelled,
        cancelled_at: event.cancelled_at,
        updated_at: event.cancelled_at
    }
  end

  # Private functions

  defp validate_items(items) when is_list(items) and length(items) > 0 do
    validated =
      Enum.reduce_while(items, {:ok, []}, fn item, {:ok, acc} ->
        case validate_item(item) do
          {:ok, validated_item} -> {:cont, {:ok, [validated_item | acc]}}
          {:error, _} = error -> {:halt, error}
        end
      end)

    case validated do
      {:ok, list} -> {:ok, Enum.reverse(list)}
      error -> error
    end
  end

  defp validate_items(_), do: {:error, :invalid_items}

  defp validate_item(item) do
    with {:ok, _} <- validate_field(item, "product_id", :string),
         {:ok, quantity} <- validate_field(item, "quantity", :integer),
         {:ok, _} <- validate_field(item, "unit_price", :number) do
      if quantity > 0 do
        {:ok, item}
      else
        {:error, :invalid_quantity}
      end
    end
  end

  defp validate_field(map, field, :string) do
    case map[field] || map[String.to_atom(field)] do
      nil -> {:error, "#{field} is required"}
      value when is_binary(value) -> {:ok, value}
      _ -> {:error, "#{field} must be a string"}
    end
  end

  defp validate_field(map, field, :integer) do
    case map[field] || map[String.to_atom(field)] do
      nil -> {:error, "#{field} is required"}
      value when is_integer(value) -> {:ok, value}
      _ -> {:error, "#{field} must be an integer"}
    end
  end

  defp validate_field(map, field, :number) do
    case map[field] || map[String.to_atom(field)] do
      nil ->
        {:error, "#{field} is required"}

      value when is_number(value) ->
        {:ok, value}

      %Decimal{} = value ->
        {:ok, Decimal.to_float(value)}

      value when is_binary(value) ->
        case Decimal.parse(value) do
          {decimal, ""} -> {:ok, Decimal.to_float(decimal)}
          _ -> {:error, "#{field} must be a valid number"}
        end

      _ ->
        {:error, "#{field} must be a number"}
    end
  end

  defp calculate_total(items) do
    total =
      Enum.reduce(items, Decimal.new(0), fn item, acc ->
        quantity = item["quantity"] || item[:quantity]
        unit_price = item["unit_price"] || item[:unit_price]

        # unit_price を Decimal に変換
        price_decimal =
          case unit_price do
            %Decimal{} = d ->
              d

            n when is_number(n) ->
              Decimal.new(n)

            s when is_binary(s) ->
              case Decimal.parse(s) do
                {d, ""} -> d
                _ -> Decimal.new(0)
              end

            _ ->
              Decimal.new(0)
          end

        # 数量と価格を掛ける
        item_total = Decimal.mult(price_decimal, Decimal.new(quantity))
        Decimal.add(acc, item_total)
      end)

    Money.new(total)
  end

  defp ensure_entity_id(%EntityId{} = id), do: {:ok, id}
  defp ensure_entity_id(id) when is_binary(id), do: EntityId.from_string(id)
  defp ensure_entity_id(_), do: {:error, "Invalid UUID"}
end
