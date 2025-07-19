defmodule Shared.Domain.Saga.CommandDispatcherBehaviour do
  @moduledoc """
  コマンドディスパッチャーのビヘイビア定義
  """

  @type command :: map()
  @type result :: {:ok, any()} | {:error, String.t()}

  @callback dispatch_command(command()) :: result()
  @callback dispatch_commands([command()]) :: result()
end
