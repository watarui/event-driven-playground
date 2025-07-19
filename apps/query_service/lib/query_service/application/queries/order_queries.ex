defmodule QueryService.Application.Queries.OrderQueries do
  @moduledoc """
  Order-related query definitions
  """

  defmodule GetOrder do
    @moduledoc """
    Get single order query
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
    def query_type, do: "order.get"

    defp validate_id(nil), do: {:error, "ID is required"}
    defp validate_id(id) when is_binary(id), do: {:ok, id}
    defp validate_id(_), do: {:error, "ID must be a string"}
  end

  defmodule ListOrders do
    @moduledoc """
    List orders query
    """
    use QueryService.Application.Queries.BaseQuery

    defstruct [:limit, :offset, :sort_by, :sort_order, :metadata]

    @type t :: %__MODULE__{
            limit: integer() | nil,
            offset: integer() | nil,
            sort_by: String.t() | nil,
            sort_order: :asc | :desc | nil,
            metadata: map() | nil
          }

    @impl true
    def validate(params) do
      with {:ok, limit} <- validate_limit(params["limit"] || params[:limit]),
           {:ok, offset} <- validate_offset(params["offset"] || params[:offset]),
           {:ok, sort_by} <- validate_sort_by(params["sort_by"] || params[:sort_by]),
           {:ok, sort_order} <- validate_sort_order(params["sort_order"] || params[:sort_order]) do
        {:ok,
         %__MODULE__{
           limit: limit,
           offset: offset,
           sort_by: sort_by,
           sort_order: sort_order,
           metadata: params["metadata"] || params[:metadata]
         }}
      end
    end

    @impl true
    def query_type, do: "order.list"

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

    defp validate_sort_by(nil), do: {:ok, "created_at"}

    defp validate_sort_by(field) when field in ["created_at", "updated_at", "total_amount"],
      do: {:ok, field}

    defp validate_sort_by(_), do: {:error, "Invalid sort field"}

    defp validate_sort_order(nil), do: {:ok, :desc}
    defp validate_sort_order("asc"), do: {:ok, :asc}
    defp validate_sort_order("desc"), do: {:ok, :desc}
    defp validate_sort_order(:asc), do: {:ok, :asc}
    defp validate_sort_order(:desc), do: {:ok, :desc}
    defp validate_sort_order(_), do: {:error, "Sort order must be 'asc' or 'desc'"}
  end
end
