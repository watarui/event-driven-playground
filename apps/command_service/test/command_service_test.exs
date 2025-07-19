defmodule CommandServiceTest do
  use ExUnit.Case
  doctest CommandService

  test "greets the world" do
    assert CommandService.hello() == :world
  end
end
