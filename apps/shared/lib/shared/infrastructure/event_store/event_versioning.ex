defmodule Shared.Infrastructure.EventStore.EventVersioning do
  @moduledoc """
  イベントのバージョニングとマイグレーションを管理するモジュール

  イベントスキーマの進化に対応し、古いイベントを新しい形式に変換する
  """

  @doc """
  イベントのバージョン管理のビヘイビア
  """
  @callback current_version() :: integer()
  @callback upcast(event :: map(), from_version :: integer(), to_version :: integer()) :: map()
  @callback downcast(event :: map(), from_version :: integer(), to_version :: integer()) :: map()

  @doc """
  イベントを現在のバージョンにアップキャストする
  """
  def upcast_event(event_type, event_data, event_version) do
    versioning_module = get_versioning_module(event_type)

    if versioning_module do
      current_version = versioning_module.current_version()

      if event_version < current_version do
        versioning_module.upcast(event_data, event_version, current_version)
      else
        event_data
      end
    else
      # バージョニングモジュールがない場合はそのまま返す
      event_data
    end
  end

  @doc """
  イベントを特定のバージョンにダウンキャストする
  """
  def downcast_event(event_type, event_data, target_version) do
    versioning_module = get_versioning_module(event_type)

    if versioning_module do
      current_version = versioning_module.current_version()

      if target_version < current_version do
        versioning_module.downcast(event_data, current_version, target_version)
      else
        event_data
      end
    else
      event_data
    end
  end

  @doc """
  イベントタイプに対応するバージョニングモジュールを取得する
  """
  def get_versioning_module(event_type) do
    # イベントタイプからバージョニングモジュール名を生成
    versioning_module_name = "#{event_type}.Versioning"

    try do
      String.to_existing_atom("Elixir.#{versioning_module_name}")
    rescue
      ArgumentError -> nil
    end
  end

  @doc """
  バージョニング設定を登録する
  """
  def register_versioning(event_type, versioning_module) do
    :persistent_term.put({__MODULE__, event_type}, versioning_module)
  end

  @doc """
  登録されたバージョニング設定を取得する
  """
  def get_registered_versioning(event_type) do
    :persistent_term.get({__MODULE__, event_type}, nil)
  end
end
