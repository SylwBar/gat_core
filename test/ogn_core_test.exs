defmodule OGNCoreTest do
  use ExUnit.Case
  doctest OGNCore

  test "greets the world" do
    assert OGNCore.hello() == :world
  end

  test "try break build" do
    assert OGNCore.hello() != :world
  end
end
