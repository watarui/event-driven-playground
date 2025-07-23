import { gql } from "@apollo/client"

// Order Mutations
export const CREATE_ORDER = gql`
  mutation CreateOrder($customerId: ID!, $items: [OrderItemInput!]!) {
    createOrder(customerId: $customerId, items: $items) {
      id
      customerId
      status
      totalAmount {
        amount
        currency
      }
      items {
        productId
        quantity
        price {
          amount
          currency
        }
      }
      createdAt
    }
  }
`

export const UPDATE_ORDER_STATUS = gql`
  mutation UpdateOrderStatus($id: ID!, $status: String!) {
    updateOrderStatus(id: $id, status: $status) {
      id
      status
      updatedAt
    }
  }
`

export const CANCEL_ORDER = gql`
  mutation CancelOrder($id: ID!) {
    cancelOrder(id: $id) {
      id
      status
      updatedAt
    }
  }
`

// Product Mutations
export const CREATE_PRODUCT = gql`
  mutation CreateProduct(
    $name: String!
    $description: String
    $price: MoneyInput!
    $stock: Int!
    $categoryId: ID!
  ) {
    createProduct(
      name: $name
      description: $description
      price: $price
      stock: $stock
      categoryId: $categoryId
    ) {
      id
      name
      description
      price {
        amount
        currency
      }
      stock
      categoryId
    }
  }
`

export const UPDATE_PRODUCT = gql`
  mutation UpdateProduct(
    $id: ID!
    $name: String
    $description: String
    $price: MoneyInput
    $stock: Int
  ) {
    updateProduct(
      id: $id
      name: $name
      description: $description
      price: $price
      stock: $stock
    ) {
      id
      name
      description
      price {
        amount
        currency
      }
      stock
      updatedAt
    }
  }
`

// Category Mutations
export const CREATE_CATEGORY = gql`
  mutation CreateCategory($name: String!, $description: String) {
    createCategory(name: $name, description: $description) {
      id
      name
      description
    }
  }
`

export const UPDATE_CATEGORY = gql`
  mutation UpdateCategory($id: ID!, $name: String, $description: String) {
    updateCategory(id: $id, name: $name, description: $description) {
      id
      name
      description
      updatedAt
    }
  }
`
