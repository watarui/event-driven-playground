defmodule CommandService.Domain.Services.InventoryService do
  @moduledoc """
  在庫管理ドメインサービス

  在庫の確認、予約、解放などの複雑なビジネスロジックを提供する。
  """

  alias Shared.Domain.ValueObjects.EntityId
  alias Shared.Domain.Errors.{BusinessRuleError, ValidationError}

  require Logger

  # 在庫状態の定義
  @type inventory_status :: :available | :reserved | :sold | :damaged | :in_transit

  @type inventory_item :: %{
          product_id: EntityId.t(),
          quantity: integer(),
          status: inventory_status(),
          warehouse_id: String.t() | nil,
          reserved_until: DateTime.t() | nil
        }

  @doc """
  在庫を確認する
  """
  @spec check_availability(String.t() | EntityId.t(), integer()) ::
          {:ok, boolean()} | {:error, atom(), map()}
  def check_availability(product_id, requested_quantity) when requested_quantity > 0 do
    with {:ok, available_quantity} <- get_available_quantity(product_id) do
      {:ok, available_quantity >= requested_quantity}
    end
  end

  def check_availability(_, quantity) when quantity <= 0 do
    {:error, ValidationError, %{field: "quantity", reason: "Quantity must be positive"}}
  end

  @doc """
  在庫を予約する
  """
  @spec reserve_inventory(String.t() | EntityId.t(), integer(), keyword()) ::
          {:ok, map()} | {:error, atom(), map()}
  def reserve_inventory(product_id, quantity, opts \\ []) do
    reservation_id = Keyword.get(opts, :reservation_id, EntityId.generate())
    duration = Keyword.get(opts, :duration_minutes, 30)
    order_id = Keyword.get(opts, :order_id)

    with {:ok, true} <- check_availability(product_id, quantity),
         {:ok, _} <- validate_reservation_limit(product_id, quantity),
         reserved_until <- calculate_reservation_expiry(duration) do
      reservation = %{
        reservation_id: reservation_id,
        product_id: product_id,
        quantity: quantity,
        order_id: order_id,
        reserved_at: DateTime.utc_now(),
        reserved_until: reserved_until,
        status: :reserved
      }

      # 実際の実装では、永続化層で在庫を更新
      Logger.info("Reserved #{quantity} units of product #{product_id}")

      {:ok, reservation}
    else
      {:ok, false} ->
        {:error, BusinessRuleError,
         %{
           rule: "insufficient_inventory",
           context: %{product_id: product_id, requested: quantity}
         }}

      error ->
        error
    end
  end

  @doc """
  予約を解放する
  """
  @spec release_reservation(String.t() | EntityId.t()) :: :ok | {:error, atom(), map()}
  def release_reservation(reservation_id) do
    # 実際の実装では、予約を検索して解放
    Logger.info("Released reservation #{reservation_id}")
    :ok
  end

  @doc """
  在庫を確定する（予約から実際の消費へ）
  """
  @spec confirm_inventory(String.t() | EntityId.t(), String.t()) ::
          :ok | {:error, atom(), map()}
  def confirm_inventory(reservation_id, order_id) do
    # 実際の実装では、予約を確定して在庫を減らす
    Logger.info("Confirmed inventory for reservation #{reservation_id}, order #{order_id}")
    :ok
  end

  @doc """
  複数商品の在庫を一括チェックする
  """
  @spec check_availability_batch([map()]) ::
          {:ok, %{available: [map()], unavailable: [map()]}} | {:error, atom(), map()}
  def check_availability_batch(items) when is_list(items) do
    results =
      Enum.map(items, fn item ->
        case check_availability(item.product_id, item.quantity) do
          {:ok, true} -> {:available, item}
          {:ok, false} -> {:unavailable, item}
          {:error, _, _} -> {:error, item}
        end
      end)

    available =
      results
      |> Enum.filter(&match?({:available, _}, &1))
      |> Enum.map(fn {:available, item} -> item end)

    unavailable =
      results
      |> Enum.filter(&match?({:unavailable, _}, &1))
      |> Enum.map(fn {:unavailable, item} -> item end)

    errors =
      results
      |> Enum.filter(&match?({:error, _}, &1))

    if Enum.empty?(errors) do
      {:ok, %{available: available, unavailable: unavailable}}
    else
      {:error, ValidationError, %{errors: %{items: "Some items have invalid data"}}}
    end
  end

  @doc """
  在庫アラートをチェックする
  """
  @spec check_low_stock_alert(String.t() | EntityId.t(), integer()) ::
          {:ok, :normal | :low | :critical} | {:error, atom(), map()}
  def check_low_stock_alert(product_id, threshold \\ 10) do
    with {:ok, quantity} <- get_available_quantity(product_id) do
      status =
        cond do
          quantity == 0 -> :critical
          quantity <= threshold -> :low
          true -> :normal
        end

      {:ok, status}
    end
  end

  @doc """
  在庫移動を記録する
  """
  @spec transfer_inventory(String.t(), String.t(), String.t(), integer(), keyword()) ::
          {:ok, map()} | {:error, atom(), map()}
  def transfer_inventory(product_id, from_warehouse, to_warehouse, quantity, opts \\ []) do
    reason = Keyword.get(opts, :reason, "transfer")

    with {:ok, true} <- validate_warehouses(from_warehouse, to_warehouse),
         {:ok, true} <- check_warehouse_stock(product_id, from_warehouse, quantity) do
      transfer = %{
        transfer_id: EntityId.generate(),
        product_id: product_id,
        from_warehouse: from_warehouse,
        to_warehouse: to_warehouse,
        quantity: quantity,
        reason: reason,
        initiated_at: DateTime.utc_now(),
        status: :in_transit
      }

      Logger.info("Initiated inventory transfer: #{inspect(transfer)}")
      {:ok, transfer}
    end
  end

  # Private functions

  defp get_available_quantity(product_id) do
    # 実際の実装では、データベースから取得
    # ここではモック実装
    {:ok, 100}
  end

  defp validate_reservation_limit(product_id, quantity) do
    # 商品ごとの予約上限をチェック
    max_reservation = 50

    if quantity <= max_reservation do
      {:ok, :valid}
    else
      {:error, BusinessRuleError,
       %{
         rule: "reservation_limit_exceeded",
         context: %{product_id: product_id, max: max_reservation, requested: quantity}
       }}
    end
  end

  defp calculate_reservation_expiry(duration_minutes) do
    DateTime.utc_now()
    |> DateTime.add(duration_minutes * 60, :second)
  end

  defp validate_warehouses(from, to) when from == to do
    {:error, ValidationError,
     %{field: "warehouse", reason: "Source and destination must be different"}}
  end

  defp validate_warehouses(_, _), do: {:ok, true}

  defp check_warehouse_stock(product_id, warehouse_id, quantity) do
    # 実際の実装では、特定倉庫の在庫をチェック
    {:ok, true}
  end
end
