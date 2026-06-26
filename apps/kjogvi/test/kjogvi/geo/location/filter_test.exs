defmodule Kjogvi.Geo.Location.FilterTest do
  use ExUnit.Case, async: true

  alias Kjogvi.Geo.Location.Filter

  describe "%Filter{}" do
    test "is a blank, no-op filter by default" do
      assert %Filter{exclude_specials: false, exclude_sections: false} = %Filter{}
    end
  end

  describe "for_checklist_input/0" do
    test "excludes specials" do
      assert %Filter{exclude_specials: true, exclude_sections: false} =
               Filter.for_checklist_input()
    end
  end

  describe "for_parent_pick/0" do
    test "excludes specials and sections" do
      assert %Filter{exclude_specials: true, exclude_sections: true} = Filter.for_parent_pick()
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
