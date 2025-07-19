defmodule ClientServiceTest do
  use ExUnit.Case
  doctest ClientService

  test "greets the world" do
    assert ClientService.hello() == :world
  end
end
