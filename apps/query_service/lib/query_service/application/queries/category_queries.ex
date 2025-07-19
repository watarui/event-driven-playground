defmodule QueryService.Application.Queries.CategoryQueries do
  @moduledoc """
  カテゴリに関するクエリ定義
  """

  defmodule GetCategory do
    @moduledoc """
    単一カテゴリ取得クエリ
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
    def query_type, do: "category.get"

    defp validate_id(nil), do: {:error, "ID is required"}
    defp validate_id(id) when is_binary(id), do: {:ok, id}
    defp validate_id(_), do: {:error, "ID must be a string"}
  end

  defmodule ListCategories do
    @moduledoc """
    カテゴリ一覧取得クエリ
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
    def query_type, do: "category.list"

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

    defp validate_sort_by(field) when field in ["name", "created_at", "updated_at"],
      do: {:ok, field}

    defp validate_sort_by(_), do: {:error, "Invalid sort field"}

    defp validate_sort_order(nil), do: {:ok, :asc}
    defp validate_sort_order("asc"), do: {:ok, :asc}
    defp validate_sort_order("desc"), do: {:ok, :desc}
    defp validate_sort_order(:asc), do: {:ok, :asc}
    defp validate_sort_order(:desc), do: {:ok, :desc}
    defp validate_sort_order(_), do: {:error, "Sort order must be 'asc' or 'desc'"}
  end

  defmodule SearchCategories do
    @moduledoc """
    カテゴリ検索クエリ
    """
    use QueryService.Application.Queries.BaseQuery

    @enforce_keys [:search_term]
    defstruct [:search_term, :limit, :offset, :metadata]

    @type t :: %__MODULE__{
            search_term: String.t(),
            limit: integer() | nil,
            offset: integer() | nil,
            metadata: map() | nil
          }

    @impl true
    def validate(params) do
      with {:ok, search_term} <-
             validate_search_term(params["search_term"] || params[:search_term]),
           {:ok, limit} <- validate_limit(params["limit"] || params[:limit]),
           {:ok, offset} <- validate_offset(params["offset"] || params[:offset]) do
        {:ok,
         %__MODULE__{
           search_term: search_term,
           limit: limit,
           offset: offset,
           metadata: params["metadata"] || params[:metadata]
         }}
      end
    end

    @impl true
    def query_type, do: "category.search"

    defp validate_search_term(nil), do: {:error, "Search term is required"}
    defp validate_search_term(term) when is_binary(term) and byte_size(term) > 0, do: {:ok, term}
    defp validate_search_term(_), do: {:error, "Search term must be a non-empty string"}

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
