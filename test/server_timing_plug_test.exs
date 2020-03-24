defmodule ServerTimingPlugTest do
  use ExUnit.Case
  doctest ServerTimingPlug

  test "greets the world" do
    assert ServerTimingPlug.hello() == :world
  end
end
