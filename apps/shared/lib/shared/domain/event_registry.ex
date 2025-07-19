defmodule Shared.Domain.EventRegistry do
  @moduledoc """
  イベントタイプとモジュールのマッピングを管理
  """
  
  @type event_type :: String.t() | atom()
  @type event_module :: module()
  
  @doc """
  登録されているすべてのイベントマッピングを返す
  """
  @spec event_mappings() :: %{event_type() => event_module()}
  def event_mappings do
    %{
      # Category events
      "category.created" => Shared.Domain.Events.CategoryEvents.CategoryCreated,
      "category.updated" => Shared.Domain.Events.CategoryEvents.CategoryUpdated,
      "category.deleted" => Shared.Domain.Events.CategoryEvents.CategoryDeleted,
      
      # Product events
      "product.created" => Shared.Domain.Events.ProductEvents.ProductCreated,
      "product.updated" => Shared.Domain.Events.ProductEvents.ProductUpdated,
      "product.deleted" => Shared.Domain.Events.ProductEvents.ProductDeleted,
      "product.price_changed" => Shared.Domain.Events.ProductEvents.ProductPriceChanged,
      
      # Order events
      "order.created" => Shared.Domain.Events.OrderEvents.OrderCreated,
      "order.confirmed" => Shared.Domain.Events.OrderEvents.OrderConfirmed,
      "order.cancelled" => Shared.Domain.Events.OrderEvents.OrderCancelled,
      "order.item_reserved" => Shared.Domain.Events.OrderEvents.OrderItemReserved,
      "order.payment_processed" => Shared.Domain.Events.OrderEvents.OrderPaymentProcessed
    }
  end
  
  @doc """
  イベントタイプからモジュールを取得
  """
  @spec get_module(event_type()) :: {:ok, event_module()} | {:error, :not_found}
  def get_module(event_type) when is_binary(event_type) do
    case Map.get(event_mappings(), event_type) do
      nil ->
        # フォールバック: event_typeをモジュール名として解釈
        try do
          module = String.to_existing_atom("Elixir.#{event_type}")
          if Code.ensure_loaded?(module), do: {:ok, module}, else: {:error, :not_found}
        rescue
          _ -> {:error, :not_found}
        end
        
      module ->
        {:ok, module}
    end
  end
  
  def get_module(event_type) when is_atom(event_type) do
    get_module(to_string(event_type))
  end
  
  @doc """
  モジュールからイベントタイプを取得
  """
  @spec get_event_type(event_module()) :: {:ok, event_type()} | {:error, :not_found}
  def get_event_type(module) when is_atom(module) do
    # まずモジュールの event_type/0 関数を試す
    if function_exported?(module, :event_type, 0) do
      {:ok, module.event_type()}
    else
      # マッピングから逆引き
      case Enum.find(event_mappings(), fn {_type, mod} -> mod == module end) do
        {event_type, _} -> {:ok, event_type}
        nil -> {:error, :not_found}
      end
    end
  end
  
  @doc """
  イベントタイプからモジュールを取得（例外を投げる）
  """
  @spec get_module!(event_type()) :: event_module()
  def get_module!(event_type) do
    case get_module(event_type) do
      {:ok, module} -> module
      {:error, :not_found} -> raise "Unknown event type: #{inspect(event_type)}"
    end
  end
end