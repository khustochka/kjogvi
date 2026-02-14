defmodule Kjogvi.GeoTest do
  use Kjogvi.DataCase, async: true

  alias Kjogvi.Geo

  describe "cards_count/1" do
    test "returns 0 when no cards exist for the location" do
      location = insert(:location)

      assert Geo.cards_count(location.id) == 0
    end

    test "counts cards for the given location" do
      location = insert(:location)
      insert(:card, location: location)
      insert(:card, location: location)

      assert Geo.cards_count(location.id) == 2
    end

    test "does not count cards at other locations" do
      location = insert(:location)
      other_location = insert(:location)
      insert(:card, location: location)
      insert(:card, location: other_location)

      assert Geo.cards_count(location.id) == 1
    end
  end

  describe "children_count/1" do
    test "returns 0 when location has no children" do
      location = insert(:location)

      assert Geo.children_count(location.id) == 0
    end

    test "counts direct children" do
      parent = insert(:location)
      insert(:location, ancestry: [parent.id])
      insert(:location, ancestry: [parent.id])

      assert Geo.children_count(parent.id) == 2
    end

    test "counts nested descendants" do
      grandparent = insert(:location)
      parent = insert(:location, ancestry: [grandparent.id])
      insert(:location, ancestry: [grandparent.id, parent.id])

      assert Geo.children_count(grandparent.id) == 2
    end

    test "does not count unrelated locations" do
      location = insert(:location)
      insert(:location)

      assert Geo.children_count(location.id) == 0
    end
  end
end
