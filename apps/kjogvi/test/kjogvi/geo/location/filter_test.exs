defmodule Kjogvi.Geo.Location.FilterTest do
  use ExUnit.Case, async: true

  alias Kjogvi.Geo.Location.Filter

  describe "%Filter{}" do
    test "is a blank, no-op filter by default" do
      assert %Filter{exclude_specials: false, exclude_sections: false} = %Filter{}
    end
  end

  describe "for_checklist_input/0" do
    test "excludes specials and disabled" do
      assert %Filter{exclude_specials: true, exclude_sections: false, exclude_disabled: true} =
               Filter.for_checklist_input()
    end
  end

  describe "for_parent_pick/0" do
    test "excludes specials, sections and disabled" do
      assert %Filter{exclude_specials: true, exclude_sections: true, exclude_disabled: true} =
               Filter.for_parent_pick()
    end
  end

  describe "for_common_parent_pick/0" do
    test "excludes specials, sections and disabled, common only" do
      assert %Filter{
               only_common: true,
               exclude_specials: true,
               exclude_sections: true,
               exclude_disabled: true
             } = Filter.for_common_parent_pick()
    end
  end

  describe "for_special_members/1" do
    test "excludes specials, unrestricted without a parent" do
      assert %Filter{exclude_specials: true, within: nil} = Filter.for_special_members()
    end

    test "restricts to the parent's descendants" do
      parent = %Kjogvi.Geo.Location{id: 5, location_type: :country}

      assert %Filter{exclude_specials: true, within: ^parent} =
               Filter.for_special_members(parent)
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
