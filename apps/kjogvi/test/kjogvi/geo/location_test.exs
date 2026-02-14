defmodule Kjogvi.Geo.LocationTest do
  use Kjogvi.DataCase, async: true

  alias Kjogvi.Geo.Location

  describe "changeset/2" do
    test "valid with required fields" do
      changeset =
        Location.changeset(
          %Location{
            slug: "test-loc",
            name_en: "Test",
            ancestry: [],
            is_private: false,
            is_patch: false,
            is_5mr: false
          },
          %{}
        )

      assert changeset.valid?
    end

    test "invalid without slug" do
      changeset =
        Location.changeset(
          %Location{
            name_en: "Test",
            ancestry: [],
            is_private: false,
            is_patch: false,
            is_5mr: false
          },
          %{}
        )

      assert %{slug: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without name_en" do
      changeset =
        Location.changeset(
          %Location{
            slug: "test-loc",
            ancestry: [],
            is_private: false,
            is_patch: false,
            is_5mr: false
          },
          %{}
        )

      assert %{name_en: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires all mandatory fields" do
      changeset = Location.changeset(%Location{}, %{})

      errors = errors_on(changeset)
      assert errors[:slug]
      assert errors[:name_en]
    end
  end

  describe "full_name/1" do
    test "returns name_en for non-patch location" do
      location = %Location{name_en: "Assiniboine Park", is_patch: false, cached_parent: nil}
      assert Location.full_name(location) == "Assiniboine Park"
    end

    test "returns parent - name for patch location with cached parent" do
      parent = %Location{name_en: "Wolseley"}
      location = %Location{name_en: "Yard", is_patch: true, cached_parent: parent}
      assert Location.full_name(location) == "Wolseley - Yard"
    end

    test "returns just name_en for patch without cached parent" do
      location = %Location{name_en: "Yard", is_patch: true, cached_parent: nil}
      assert Location.full_name(location) == "Yard"
    end
  end

  describe "name_local_part/1" do
    test "returns name without city when no cached city" do
      location = %Location{
        name_en: "Assiniboine Park",
        is_patch: false,
        cached_parent: nil,
        cached_city: nil
      }

      assert Location.name_local_part(location) == "Assiniboine Park"
    end

    test "includes city when cached city is present" do
      city = %Location{name_en: "Winnipeg"}

      location = %Location{
        name_en: "Assiniboine Park",
        is_patch: false,
        cached_parent: nil,
        cached_city: city
      }

      assert Location.name_local_part(location) == "Assiniboine Park, Winnipeg"
    end

    test "includes parent name for non-patch with cached parent" do
      parent = %Location{name_en: "Fort Garry"}
      city = %Location{name_en: "Winnipeg"}

      location = %Location{
        name_en: "Duck Pond",
        is_patch: false,
        cached_parent: parent,
        cached_city: city
      }

      assert Location.name_local_part(location) == "Duck Pond, Fort Garry, Winnipeg"
    end
  end

  describe "name_administrative_part/1" do
    test "returns empty string when no subdivision or country" do
      location = %Location{cached_subdivision: nil, cached_country: nil}
      assert Location.name_administrative_part(location) == ""
    end

    test "returns country only" do
      country = %Location{name_en: "Canada"}
      location = %Location{cached_subdivision: nil, cached_country: country}
      assert Location.name_administrative_part(location) == "Canada"
    end

    test "returns subdivision and country" do
      country = %Location{name_en: "Canada"}
      subdivision = %Location{name_en: "Manitoba"}
      location = %Location{cached_subdivision: subdivision, cached_country: country}
      assert Location.name_administrative_part(location) == "Manitoba, Canada"
    end
  end

  describe "long_name/1" do
    test "combines local and administrative parts" do
      country = %Location{name_en: "Canada"}
      subdivision = %Location{name_en: "Manitoba"}

      location = %Location{
        name_en: "Assiniboine Park",
        is_patch: false,
        cached_parent: nil,
        cached_city: nil,
        cached_subdivision: subdivision,
        cached_country: country
      }

      assert Location.long_name(location) == "Assiniboine Park, Manitoba, Canada"
    end

    test "returns just local part when no administrative part" do
      location = %Location{
        name_en: "Assiniboine Park",
        is_patch: false,
        cached_parent: nil,
        cached_city: nil,
        cached_subdivision: nil,
        cached_country: nil
      }

      assert Location.long_name(location) == "Assiniboine Park"
    end
  end

  describe "to_flag_emoji/1" do
    test "returns flag emoji for iso code" do
      location = %Location{iso_code: "ca"}
      assert Location.to_flag_emoji(location) == "🇨🇦"
    end

    test "returns empty string for nil iso code" do
      location = %Location{iso_code: nil}
      assert Location.to_flag_emoji(location) == ""
    end
  end

  describe "raw_public_location/1" do
    test "returns the location itself when not private" do
      location = %Location{id: 1, is_private: false}
      assert Location.raw_public_location(location) == location
    end

    test "returns first non-private ancestor when ancestors are loaded" do
      public_ancestor = %Location{id: 10, is_private: false}
      private_ancestor = %Location{id: 11, is_private: true}

      location = %Location{
        id: 1,
        is_private: true,
        ancestors: [public_ancestor, private_ancestor]
      }

      assert Location.raw_public_location(location) ==
               private_ancestor |> then(fn _ -> public_ancestor end)

      # ancestors are reversed, then first non-private is found
      result = Location.raw_public_location(location)
      refute result.is_private
    end
  end

  describe "ancestors/1" do
    test "returns ancestors in ancestry order" do
      grandparent = insert(:location)
      parent = insert(:location, ancestry: [grandparent.id])
      child = insert(:location, ancestry: [grandparent.id, parent.id])

      ancestors = Location.ancestors(child)
      assert length(ancestors) == 2
      assert Enum.map(ancestors, & &1.id) == [grandparent.id, parent.id]
    end

    test "returns empty list for root location" do
      location = insert(:location, ancestry: [])

      assert Location.ancestors(location) == []
    end
  end

  describe "add_ancestors/1" do
    test "populates the ancestors virtual field" do
      parent = insert(:location)
      child = insert(:location, ancestry: [parent.id])

      result = Location.add_ancestors(child)
      assert length(result.ancestors) == 1
      assert hd(result.ancestors).id == parent.id
    end
  end

  describe "preload_ancestors/1" do
    test "loads ancestors for a list of locations" do
      grandparent = insert(:location)
      parent = insert(:location, ancestry: [grandparent.id])
      child = insert(:location, ancestry: [grandparent.id, parent.id])

      [result] = Location.preload_ancestors([child])
      assert length(result.ancestors) == 2
      assert Enum.map(result.ancestors, & &1.id) == [grandparent.id, parent.id]
    end

    test "handles locations with no ancestry" do
      location = insert(:location, ancestry: [])

      [result] = Location.preload_ancestors([location])
      assert result.ancestors == []
    end
  end

  describe "set_public_location_changeset/1" do
    test "sets cached_public_location_id for private location" do
      public_parent = insert(:location, is_private: false)
      private_loc = insert(:location, is_private: true, ancestry: [public_parent.id])

      changeset = Location.set_public_location_changeset(private_loc)
      assert get_change(changeset, :cached_public_location_id) == public_parent.id
    end

    test "returns unchanged changeset for public location" do
      location = insert(:location, is_private: false)

      changeset = Location.set_public_location_changeset(location)
      assert changeset.changes == %{}
    end
  end
end
