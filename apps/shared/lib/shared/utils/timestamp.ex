defmodule Shared.Utils.Timestamp do
  @moduledoc """
  Timestamp 変換ユーティリティ
  """

  @doc """
  DateTime を Unix タイムスタンプに変換
  """
  def from_datetime(nil), do: 0

  def from_datetime(%DateTime{} = datetime) do
    DateTime.to_unix(datetime, :second)
  end

  @doc """
  Unix タイムスタンプを DateTime に変換
  """
  def to_datetime(nil), do: nil
  def to_datetime(0), do: nil

  def to_datetime(timestamp) when is_integer(timestamp) do
    DateTime.from_unix!(timestamp, :second)
  end
end
