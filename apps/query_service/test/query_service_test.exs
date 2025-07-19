defmodule QueryServiceTest do
  use ExUnit.Case
  doctest QueryService

  test "greets the world" do
    assert QueryService.hello() == :world
  end
end
