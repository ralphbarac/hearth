defmodule HearthGroceryTest do
  use ExUnit.Case
  doctest HearthGrocery

  test "greets the world" do
    assert HearthGrocery.hello() == :world
  end
end
