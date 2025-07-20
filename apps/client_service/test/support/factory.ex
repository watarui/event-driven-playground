defmodule ClientService.Factory do
  @moduledoc """
  テストデータファクトリー
  ExMachina を使用したテストデータ生成
  """

  use ExMachina

  @doc """
  ユーザーファクトリー
  """
  def user_factory do
    %{
      id: sequence(:user_id, &"user-#{&1}"),
      email: sequence(:email, &"user#{&1}@example.com"),
      role: :reader,
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  def admin_user_factory do
    struct!(
      user_factory(),
      %{
        email: sequence(:email, &"admin#{&1}@example.com"),
        role: :admin
      }
    )
  end

  def writer_user_factory do
    struct!(
      user_factory(),
      %{
        email: sequence(:email, &"writer#{&1}@example.com"),
        role: :writer
      }
    )
  end

  @doc """
  カテゴリファクトリー
  """
  def category_factory do
    %{
      id: sequence(:category_id, &"category-#{&1}"),
      name: sequence(:category_name, &"Category #{&1}"),
      description: "Test category description",
      parent_id: nil,
      active: true,
      product_count: 0,
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  @doc """
  商品ファクトリー
  """
  def product_factory do
    %{
      id: sequence(:product_id, &"product-#{&1}"),
      name: sequence(:product_name, &"Product #{&1}"),
      description: "Test product description",
      price: Decimal.new("99.99"),
      stock: 100,
      category_id: build(:category).id,
      active: true,
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  @doc """
  注文ファクトリー
  """
  def order_factory do
    items = build_list(3, :order_item)

    total_amount =
      Enum.reduce(items, Decimal.new(0), fn item, acc ->
        Decimal.add(acc, item.subtotal)
      end)

    %{
      id: sequence(:order_id, &"order-#{&1}"),
      user_id: build(:user).id,
      status: :pending,
      total_amount: total_amount,
      items: items,
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now(),
      saga_id: sequence(:saga_id, &"saga-#{&1}"),
      saga_status: "started",
      saga_current_step: "create_order",
      payment_id: nil,
      shipping_id: nil
    }
  end

  def completed_order_factory do
    struct!(
      order_factory(),
      %{
        status: :completed,
        saga_status: "completed",
        saga_current_step: "order_completed",
        payment_id: sequence(:payment_id, &"payment-#{&1}"),
        shipping_id: sequence(:shipping_id, &"shipping-#{&1}")
      }
    )
  end

  @doc """
  注文アイテムファクトリー
  """
  def order_item_factory do
    product = build(:product)
    quantity = Enum.random(1..5)
    subtotal = Decimal.mult(product.price, quantity)

    %{
      product_id: product.id,
      product_name: product.name,
      quantity: quantity,
      unit_price: product.price,
      subtotal: subtotal
    }
  end

  @doc """
  イベントファクトリー
  """
  def event_factory do
    %{
      id: sequence(:event_id, & &1),
      aggregate_id: sequence(:aggregate_id, &"aggregate-#{&1}"),
      aggregate_type: sequence([:Order, :Product, :Category]),
      event_type: sequence(["Created", "Updated", "Deleted"]),
      event_data: %{test: "data"},
      event_version: 1,
      global_sequence: sequence(:global_sequence, & &1),
      inserted_at: NaiveDateTime.utc_now()
    }
  end

  @doc """
  SAGAファクトリー
  """
  def saga_factory do
    %{
      id: sequence(:saga_id, &"saga-#{&1}"),
      saga_type: "OrderSaga",
      status: "started",
      state: %{
        order_id: build(:order).id,
        current_step: "create_order",
        handled_events: []
      },
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now(),
      correlation_id: sequence(:correlation_id, &"corr-#{&1}")
    }
  end

  def completed_saga_factory do
    struct!(
      saga_factory(),
      %{
        status: "completed",
        state: %{
          order_id: build(:order).id,
          current_step: "saga_completed",
          handled_events: ["OrderCreated", "PaymentProcessed", "OrderShipped"]
        }
      }
    )
  end

  @doc """
  GraphQL コンテキストファクトリー
  """
  def graphql_context_factory do
    user = build(:user)

    %{
      current_user: user,
      is_authenticated: true,
      is_admin: user.role == :admin
    }
  end

  def admin_context_factory do
    user = build(:admin_user)

    %{
      current_user: user,
      is_authenticated: true,
      is_admin: true
    }
  end

  @doc """
  認証トークンファクトリー
  """
  def auth_token_factory do
    user = build(:user)
    {:ok, token, _claims} = ClientService.Auth.Guardian.encode_and_sign(user)

    %{
      token: token,
      user: user,
      type: "Bearer"
    }
  end

  @doc """
  PubSub メッセージファクトリー
  """
  def pubsub_message_factory do
    %{
      id: sequence(:message_id, &"msg-#{&1}"),
      topic: sequence([:commands, :queries, :events]),
      payload: %{test: "payload"},
      timestamp: DateTime.utc_now(),
      publisher: "test-service"
    }
  end

  @doc """
  ヘルスチェックレスポンスファクトリー
  """
  def health_check_factory do
    %{
      status: :healthy,
      checks: [
        %{
          name: "database",
          status: :healthy,
          message: "Connected"
        },
        %{
          name: "pubsub",
          status: :healthy,
          message: "Connected"
        }
      ],
      timestamp: DateTime.utc_now()
    }
  end
end
