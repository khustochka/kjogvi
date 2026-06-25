defmodule Kjogvi.Geo.Location.FilterTest do
  use ExUnit.Case, async: true

  alias Kjogvi.Geo.Location.Filter

  describe "%Filter{}" do
    test "is a blank, no-op filter by default" do
      assert %Filter{exclude_specials: false} = %Filter{}
    end
  end

  describe "for_card_input/0" do
    test "excludes specials" do
      assert %Filter{exclude_specials: true} = Filter.for_card_input()
    end
  end

  describe "discombo!/1" do
    test "builds from options, validating types" do
      assert %Filter{exclude_specials: true} = Filter.discombo!(exclude_specials: true)
    end

    test "raises on an invalid type" do
      assert_raise NimbleOptions.ValidationError, fn ->
        Filter.discombo!(exclude_specials: "yes")
      end
    end
  end
end
