defmodule HelloNervesTest do
  use ExUnit.Case
  doctest HelloNerves

  test "greets the world" do
    assert HelloNerves.hello() == :world
  end
end
