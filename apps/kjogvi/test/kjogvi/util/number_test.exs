defmodule Kjogvi.Util.NumberTest do
  use ExUnit.Case, async: true

  doctest Kjogvi.Util.Number

  alias Kjogvi.Util.Number

  describe "delimit/1" do
    test "leaves numbers under a thousand untouched" do
      assert Number.delimit(0) == "0"
      assert Number.delimit(42) == "42"
      assert Number.delimit(999) == "999"
    end

    test "groups digits in threes with commas" do
      assert Number.delimit(1000) == "1,000"
      assert Number.delimit(12_345) == "12,345"
      assert Number.delimit(1_234_567) == "1,234,567"
    end
  end
end
