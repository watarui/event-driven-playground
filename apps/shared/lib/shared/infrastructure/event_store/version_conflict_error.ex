defmodule Shared.Infrastructure.EventStore.VersionConflictError do
  @moduledoc """
  アグリゲートバージョンの競合エラー
  """

  defexception [:aggregate_id, :expected_version, :actual_version]

  @impl true
  def message(%{aggregate_id: id, expected_version: expected, actual_version: actual}) do
    """
    Version conflict detected for aggregate #{id}.
    Expected version: #{expected}
    Actual version: #{actual}
    """
  end
end
