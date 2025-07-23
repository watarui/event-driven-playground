import { gql } from "@apollo/client";

// Order Queries
export const GET_ORDERS = gql`
  query GetOrders($limit: Int, $offset: Int) {
    orders(limit: $limit, offset: $offset) {
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
      updatedAt
    }
  }
`;

export const GET_ORDER_BY_ID = gql`
  query GetOrderById($id: ID!) {
    order(id: $id) {
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
      updatedAt
    }
  }
`;

// Product Queries
export const GET_PRODUCTS = gql`
  query GetProducts($categoryId: ID, $limit: Int, $offset: Int) {
    products(categoryId: $categoryId, limit: $limit, offset: $offset) {
      id
      name
      description
      price {
        amount
        currency
      }
      stock
      categoryId
      category {
        id
        name
      }
    }
  }
`;

export const GET_PRODUCT_BY_ID = gql`
  query GetProductById($id: ID!) {
    product(id: $id) {
      id
      name
      description
      price {
        amount
        currency
      }
      stock
      categoryId
      category {
        id
        name
        description
      }
    }
  }
`;

// Category Queries
export const GET_CATEGORIES = gql`
  query GetCategories {
    categories {
      id
      name
      description
    }
  }
`;

export const GET_CATEGORY_BY_ID = gql`
  query GetCategoryById($id: ID!) {
    category(id: $id) {
      id
      name
      description
      products {
        id
        name
        price {
          amount
          currency
        }
        stock
      }
    }
  }
`;
