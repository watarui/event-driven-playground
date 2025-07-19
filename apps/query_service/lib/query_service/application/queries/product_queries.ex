defmodule QueryService.Application.Queries.ProductQueries do
  @moduledoc """
  商品に関するクエリ定義
  """

  defmodule GetProduct do
    @moduledoc """
    単一商品取得クエリ
    """
    use QueryService.Application.Queries.BaseQuery

    @enforce_keys [:id]
    defstruct [:id, :metadata]

    @type t :: %__MODULE__{
            id: String.t(),
            metadata: map() | nil
          }

    @impl true
    def validate(params) do
      with {:ok, id} <- validate_id(params["id"] || params[:id]) do
        {:ok,
         %__MODULE__{
           id: id,
           metadata: params["metadata"] || params[:metadata]
         }}
      end
    end

    @impl true
    def query_type, do: "product.get"

    defp validate_id(nil), do: {:error, "ID is required"}
    defp validate_id(id) when is_binary(id), do: {:ok, id}
    defp validate_id(_), do: {:error, "ID must be a string"}
  end

  defmodule ListProducts do
    @moduledoc """
    商品一覧取得クエリ
    """
    use QueryService.Application.Queries.BaseQuery

    defstruct [
      :category_id,
      :limit,
      :offset,
      :sort_by,
      :sort_order,
      :min_price,
      :max_price,
      :metadata
    ]

    @type t :: %__MODULE__{
            category_id: String.t() | nil,
            limit: integer() | nil,
            offset: integer() | nil,
            sort_by: String.t() | nil,
            sort_order: :asc | :desc | nil,
            min_price: Decimal.t() | nil,
            max_price: Decimal.t() | nil,
            metadata: map() | nil
          }

    @impl true
    def validate(params) do
      with {:ok, category_id} <-
             validate_category_id(params["category_id"] || params[:category_id]),
           {:ok, limit} <- validate_limit(params["limit"] || params[:limit]),
           {:ok, offset} <- validate_offset(params["offset"] || params[:offset]),
           {:ok, sort_by} <- validate_sort_by(params["sort_by"] || params[:sort_by]),
           {:ok, sort_order} <- validate_sort_order(params["sort_order"] || params[:sort_order]),
           {:ok, min_price} <- validate_price(params["min_price"] || params[:min_price]),
           {:ok, max_price} <- validate_price(params["max_price"] || params[:max_price]),
           :ok <- validate_price_range(min_price, max_price) do
        {:ok,
         %__MODULE__{
           category_id: category_id,
           limit: limit,
           offset: offset,
           sort_by: sort_by,
           sort_order: sort_order,
           min_price: min_price,
           max_price: max_price,
           metadata: params["metadata"] || params[:metadata]
         }}
      end
    end

    @impl true
    def query_type, do: "product.list"

    defp validate_category_id(nil), do: {:ok, nil}
    defp validate_category_id(id) when is_binary(id), do: {:ok, id}
    defp validate_category_id(_), do: {:error, "Category ID must be a string"}

    defp validate_limit(nil), do: {:ok, 20}

    defp validate_limit(limit) when is_integer(limit) and limit > 0 and limit <= 100,
      do: {:ok, limit}

    defp validate_limit(limit) when is_binary(limit) do
      case Integer.parse(limit) do
        {value, ""} when value > 0 and value <= 100 -> {:ok, value}
        _ -> {:error, "Invalid limit"}
      end
    end

    defp validate_limit(_), do: {:error, "Limit must be between 1 and 100"}

    defp validate_offset(nil), do: {:ok, 0}
    defp validate_offset(offset) when is_integer(offset) and offset >= 0, do: {:ok, offset}

    defp validate_offset(offset) when is_binary(offset) do
      case Integer.parse(offset) do
        {value, ""} when value >= 0 -> {:ok, value}
        _ -> {:error, "Invalid offset"}
      end
    end

    defp validate_offset(_), do: {:error, "Offset must be non-negative"}

    defp validate_sort_by(nil), do: {:ok, "name"}

    defp validate_sort_by(field) when field in ["name", "price", "created_at", "updated_at"],
      do: {:ok, field}

    defp validate_sort_by(_), do: {:error, "Invalid sort field"}

    defp validate_sort_order(nil), do: {:ok, :asc}
    defp validate_sort_order("asc"), do: {:ok, :asc}
    defp validate_sort_order("desc"), do: {:ok, :desc}
    defp validate_sort_order(:asc), do: {:ok, :asc}
    defp validate_sort_order(:desc), do: {:ok, :desc}
    defp validate_sort_order(_), do: {:error, "Sort order must be 'asc' or 'desc'"}

    defp validate_price(nil), do: {:ok, nil}
    defp validate_price(%Decimal{} = price), do: {:ok, price}
    defp validate_price(price) when is_number(price) and price >= 0, do: {:ok, Decimal.new(price)}

    defp validate_price(price) when is_binary(price) do
      case Decimal.parse(price) do
        {decimal, ""} ->
          if Decimal.compare(decimal, 0) != :lt do
            {:ok, decimal}
          else
            {:error, "Price must be non-negative"}
          end

        _ ->
          {:error, "Invalid price format"}
      end
    end

    defp validate_price(_), do: {:error, "Price must be non-negative"}

    defp validate_price_range(nil, _), do: :ok
    defp validate_price_range(_, nil), do: :ok

    defp validate_price_range(min_price, max_price) do
      case Decimal.compare(min_price, max_price) do
        :gt -> {:error, "Min price must be less than or equal to max price"}
        _ -> :ok
      end
    end
  end

  defmodule SearchProducts do
    @moduledoc """
    商品検索クエリ
    """
    use QueryService.Application.Queries.BaseQuery

    @enforce_keys [:search_term]
    defstruct [:search_term, :category_id, :limit, :offset, :metadata]

    @type t :: %__MODULE__{
            search_term: String.t(),
            category_id: String.t() | nil,
            limit: integer() | nil,
            offset: integer() | nil,
            metadata: map() | nil
          }

    @impl true
    def validate(params) do
      with {:ok, search_term} <-
             validate_search_term(params["search_term"] || params[:search_term]),
           {:ok, category_id} <-
             validate_category_id(params["category_id"] || params[:category_id]),
           {:ok, limit} <- validate_limit(params["limit"] || params[:limit]),
           {:ok, offset} <- validate_offset(params["offset"] || params[:offset]) do
        {:ok,
         %__MODULE__{
           search_term: search_term,
           category_id: category_id,
           limit: limit,
           offset: offset,
           metadata: params["metadata"] || params[:metadata]
         }}
      end
    end

    @impl true
    def query_type, do: "product.search"

    defp validate_search_term(nil), do: {:error, "Search term is required"}
    defp validate_search_term(term) when is_binary(term) and byte_size(term) > 0, do: {:ok, term}
    defp validate_search_term(_), do: {:error, "Search term must be a non-empty string"}

    defp validate_category_id(nil), do: {:ok, nil}
    defp validate_category_id(id) when is_binary(id), do: {:ok, id}
    defp validate_category_id(_), do: {:error, "Category ID must be a string"}

    defp validate_limit(nil), do: {:ok, 20}

    defp validate_limit(limit) when is_integer(limit) and limit > 0 and limit <= 100,
      do: {:ok, limit}

    defp validate_limit(limit) when is_binary(limit) do
      case Integer.parse(limit) do
        {value, ""} when value > 0 and value <= 100 -> {:ok, value}
        _ -> {:error, "Invalid limit"}
      end
    end

    defp validate_limit(_), do: {:error, "Limit must be between 1 and 100"}

    defp validate_offset(nil), do: {:ok, 0}
    defp validate_offset(offset) when is_integer(offset) and offset >= 0, do: {:ok, offset}

    defp validate_offset(offset) when is_binary(offset) do
      case Integer.parse(offset) do
        {value, ""} when value >= 0 -> {:ok, value}
        _ -> {:error, "Invalid offset"}
      end
    end

    defp validate_offset(_), do: {:error, "Offset must be non-negative"}
  end
end
