defmodule CommandService.Application.Commands.CategoryCommands do
  @moduledoc """
  カテゴリに関するコマンド定義
  """

  defmodule CreateCategory do
    @moduledoc """
    カテゴリ作成コマンド
    """
    use CommandService.Application.Commands.BaseCommand

    @enforce_keys [:name]
    defstruct [:name, :description, :metadata]

    @type t :: %__MODULE__{
            name: String.t(),
            description: String.t() | nil,
            metadata: map() | nil
          }

    @impl true
    def validate(params) do
      with {:ok, name} <- validate_name(params["name"] || params[:name]) do
        {:ok,
         %__MODULE__{
           name: name,
           description: params["description"] || params[:description],
           metadata: params["metadata"] || params[:metadata]
         }}
      end
    end

    @impl true
    def command_type, do: "category.create"

    defp validate_name(nil), do: {:error, "Name is required"}
    defp validate_name(name) when is_binary(name), do: {:ok, name}
    defp validate_name(_), do: {:error, "Name must be a string"}
  end

  defmodule UpdateCategory do
    @moduledoc """
    カテゴリ更新コマンド
    """
    use CommandService.Application.Commands.BaseCommand

    @enforce_keys [:id, :name]
    defstruct [:id, :name, :description, :metadata]

    @type t :: %__MODULE__{
            id: String.t(),
            name: String.t(),
            description: String.t() | nil,
            metadata: map() | nil
          }

    @impl true
    def validate(params) do
      with {:ok, id} <- validate_id(params["id"] || params[:id]),
           {:ok, name} <- validate_name(params["name"] || params[:name]) do
        {:ok,
         %__MODULE__{
           id: id,
           name: name,
           description: params["description"] || params[:description],
           metadata: params["metadata"] || params[:metadata]
         }}
      end
    end

    @impl true
    def command_type, do: "category.update"

    defp validate_id(nil), do: {:error, "ID is required"}
    defp validate_id(id) when is_binary(id), do: {:ok, id}
    defp validate_id(_), do: {:error, "ID must be a string"}

    defp validate_name(nil), do: {:error, "Name is required"}
    defp validate_name(name) when is_binary(name), do: {:ok, name}
    defp validate_name(_), do: {:error, "Name must be a string"}
  end

  defmodule DeleteCategory do
    @moduledoc """
    カテゴリ削除コマンド
    """
    use CommandService.Application.Commands.BaseCommand

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
    def command_type, do: "category.delete"

    defp validate_id(nil), do: {:error, "ID is required"}
    defp validate_id(id) when is_binary(id), do: {:ok, id}
    defp validate_id(_), do: {:error, "ID must be a string"}
  end
end
