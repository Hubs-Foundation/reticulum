defmodule Ret.Repo.MigrationHelpersTest do
  use ExUnit.Case, async: true

  import Ret.Repo.MigrationHelpers

  describe "next_month/2" do
    setup do
      %{y: 1234}
    end

    test "when the month is December", %{y: y} do
      result = next_month(y, 12)
      assert y + 1 === result.y
      assert 1 === result.m
    end

    test "when the month is not December", %{y: y} do
      for m <- 1..11 do
        result = next_month(y, m)
        assert y === result.y
        assert m + 1 === result.m
      end
    end
  end
end
