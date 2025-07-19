defmodule Shared.Infrastructure.EventStore.Versioning.Base do
  @moduledoc """
  イベントバージョニングの基底モジュール

  イベントのバージョン管理を実装するための共通機能を提供する
  """

  @doc """
  バージョン間の変換マッピングを定義する

  例：
  ```
  version_mappings do
    # v1 -> v2
    map_version 1, 2 do
      # 新しいフィールドを追加
      Map.put(event, "new_field", "default_value")
    end
    
    # v2 -> v3
    map_version 2, 3 do
      # フィールド名を変更
      event
      |> Map.put("renamed_field", Map.get(event, "old_field"))
      |> Map.delete("old_field")
    end
  end
  ```
  """
  defmacro version_mappings(do: block) do
    quote do
      unquote(block)
    end
  end

  @doc """
  特定のバージョン間の変換を定義する
  """
  defmacro map_version(from_version, to_version, do: transformation) do
    upcast_name = :"upcast_#{from_version}_to_#{to_version}"
    downcast_name = :"downcast_#{to_version}_to_#{from_version}"

    quote do
      defp unquote(upcast_name)(event) do
        unquote(transformation)
      end

      defp unquote(downcast_name)(event) do
        # ダウンキャストはアップキャストの逆変換
        # デフォルトでは実装を要求する
        raise "Downcast from version #{unquote(to_version)} to #{unquote(from_version)} not implemented"
      end
    end
  end

  defmacro __using__(_opts) do
    quote do
      @behaviour Shared.Infrastructure.EventStore.EventVersioning

      import unquote(__MODULE__)

      @doc """
      アップキャストの実装
      """
      def upcast(event, from_version, to_version) when from_version == to_version, do: event

      def upcast(event, from_version, to_version) when from_version < to_version do
        from_version..(to_version - 1)
        |> Enum.reduce(event, fn version, acc ->
          function_name = :"upcast_#{version}_to_#{version + 1}"

          if function_exported?(__MODULE__, function_name, 1) do
            apply(__MODULE__, function_name, [acc])
          else
            raise "Upcast from version #{version} to #{version + 1} not implemented"
          end
        end)
      end

      @doc """
      ダウンキャストの実装
      """
      def downcast(event, from_version, to_version) when from_version == to_version, do: event

      def downcast(event, from_version, to_version) when from_version > to_version do
        from_version..to_version
        |> Enum.reduce(event, fn version, acc ->
          if version > to_version do
            function_name = :"downcast_#{version}_to_#{version - 1}"

            if function_exported?(__MODULE__, function_name, 1) do
              apply(__MODULE__, function_name, [acc])
            else
              raise "Downcast from version #{version} to #{version - 1} not implemented"
            end
          else
            acc
          end
        end)
      end

      # デフォルト実装をオーバーライド可能にする
      defoverridable upcast: 3, downcast: 3
    end
  end
end
