defmodule Kjogvi.Geo.LocationTest do
  use Kjogvi.DataCase, async: true

  import Kjogvi.AccountsFixtures

  alias Kjogvi.Geo.Location
  alias Kjogvi.Geo.Location.Query
  alias Kjogvi.Repo

  describe "changeset/2" do
    test "valid with required fields" do
      changeset =
        Location.changeset(
          %Location{
            slug: "test-loc",
            name_en: "Test",
            location_type: :country,
            is_private: false
          },
          %{}
        )

      assert changeset.valid?
    end

    test "invalid without location_type" do
      changeset =
        Location.changeset(
          %Location{
            slug: "test-loc",
            name_en: "Test",
            is_private: false
          },
          %{}
        )

      assert %{location_type: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without slug" do
      changeset =
        Location.changeset(
          %Location{
            name_en: "Test",
            is_private: false
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
            is_private: false
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
      assert errors[:location_type]
    end
  end

  describe "changeset/2 deriving level FKs from a parent" do
    setup do
      country = insert(:country, name_en: "Canada")

      subdivision1 =
        insert(:location,
          name_en: "Manitoba",
          location_type: :subdivision1,
          country: country
        )

      %{country: country, subdivision1: subdivision1}
    end

    test "fills the level FKs from the parent's FKs plus the parent itself", %{
      country: country,
      subdivision1: subdivision1
    } do
      changeset =
        Location.changeset(%Location{}, %{
          "slug" => "wpg",
          "name_en" => "Winnipeg",
          "is_private" => false,
          "location_type" => "city",
          "parent_id" => subdivision1.id
        })

      assert changeset.valid?
      assert get_change(changeset, :country_id) == country.id
      assert get_change(changeset, :subdivision1_id) == subdivision1.id
      assert get_change(changeset, :city_id) == nil
    end

    test "a nil parent_id clears the level FKs", %{country: country} do
      city =
        insert(:location, name_en: "Old City", location_type: :city, country: country)

      changeset = Location.changeset(city, %{"parent_id" => nil, "location_type" => "country"})

      assert get_change(changeset, :country_id) == nil
    end

    test "an absent parent_id leaves existing FKs untouched", %{country: country} do
      city =
        insert(:location, name_en: "City", location_type: :city, country: country)

      changeset = Location.changeset(city, %{"name_en" => "City Renamed"})

      refute Map.has_key?(changeset.changes, :country_id)
    end

    test "errors when the parent does not exist" do
      changeset =
        Location.changeset(%Location{}, %{
          "slug" => "x",
          "name_en" => "X",
          "is_private" => false,
          "location_type" => "city",
          "parent_id" => -1
        })

      assert %{parent_id: ["does not exist"]} = errors_on(changeset)
    end

    test "rejects a section parent (a section can never be an ancestor)", %{country: country} do
      section =
        insert(:location, name_en: "Trail", location_type: :section, country: country)

      changeset =
        Location.changeset(%Location{}, %{
          "slug" => "z",
          "name_en" => "Z",
          "is_private" => false,
          "location_type" => "section",
          "parent_id" => section.id
        })

      assert %{parent_id: ["cannot be a section"]} = errors_on(changeset)
    end

    test "rejects a special parent (a special is not a hierarchy parent)", %{country: country} do
      special =
        insert(:special, name_en: "Patch", country_id: country.id)

      changeset =
        Location.changeset(%Location{}, %{
          "slug" => "z",
          "name_en" => "Z",
          "is_private" => false,
          "location_type" => "city",
          "parent_id" => special.id
        })

      assert %{parent_id: ["cannot be a special"]} = errors_on(changeset)
    end

    test "rejects a parent at the new location's own level", %{
      country: country,
      subdivision1: subdivision1
    } do
      city =
        insert(:location,
          name_en: "Winnipeg",
          location_type: :city,
          country: country,
          subdivision1_id: subdivision1.id
        )

      changeset =
        Location.changeset(%Location{}, %{
          "slug" => "y",
          "name_en" => "Y",
          "is_private" => false,
          "location_type" => "city",
          "parent_id" => city.id
        })

      assert %{city_id: ["cannot be set for a city"]} = errors_on(changeset)
    end
  end

  describe "changeset/2 changing location_type" do
    setup do
      country = insert(:country, name_en: "Canada")

      subdivision1 =
        insert(:location,
          name_en: "Manitoba",
          location_type: :subdivision1,
          country: country
        )

      %{country: country, subdivision1: subdivision1}
    end

    test "demoting is rejected when a child sits at the new level", %{
      country: country,
      subdivision1: subdivision1
    } do
      # subdivision1 has a city child; demoting it to city collides with that child.
      insert(:location,
        name_en: "Winnipeg",
        location_type: :city,
        country: country,
        subdivision1_id: subdivision1.id
      )

      changeset =
        Location.changeset(subdivision1, %{
          "location_type" => "city",
          "parent_id" => country.id
        })

      assert %{location_type: [msg]} = errors_on(changeset)
      assert msg =~ "sub-location is at that level or above"
    end

    test "demoting is allowed when every child stays strictly below the new level", %{
      country: country,
      subdivision1: subdivision1
    } do
      # subdivision1's children are a city and a site (both below subdivision2);
      # demoting to subdivision2 leaves them strictly below.
      city =
        insert(:location,
          name_en: "Winnipeg",
          location_type: :city,
          country: country,
          subdivision1_id: subdivision1.id
        )

      insert(:location,
        name_en: "The Forks",
        location_type: :site,
        country: country,
        subdivision1_id: subdivision1.id,
        city_id: city.id
      )

      changeset =
        Location.changeset(subdivision1, %{
          "location_type" => "subdivision2",
          "parent_id" => country.id
        })

      assert changeset.valid?
    end

    test "promoting past a parent at the new level is rejected by slot occupancy", %{
      country: country,
      subdivision1: subdivision1
    } do
      city =
        insert(:location,
          name_en: "Winnipeg",
          location_type: :city,
          country: country,
          subdivision1_id: subdivision1.id
        )

      # Promote the city to subdivision1 while still parented by a subdivision1.
      changeset =
        Location.changeset(city, %{
          "location_type" => "subdivision1",
          "parent_id" => subdivision1.id
        })

      assert %{subdivision1_id: ["cannot be set for a subdivision1"]} = errors_on(changeset)
    end

    test "promoting to a valid higher level is allowed", %{
      country: country,
      subdivision1: subdivision1
    } do
      city =
        insert(:location,
          name_en: "Winnipeg",
          location_type: :city,
          country: country,
          subdivision1_id: subdivision1.id
        )

      changeset =
        Location.changeset(city, %{
          "location_type" => "subdivision1",
          "parent_id" => country.id
        })

      assert changeset.valid?
    end

    test "a type change on a childless location is allowed", %{country: country} do
      city =
        insert(:location, name_en: "Winnipeg", location_type: :city, country: country)

      changeset =
        Location.changeset(city, %{"location_type" => "site", "parent_id" => country.id})

      assert changeset.valid?
    end
  end

  describe "level_fks_from_parent/1" do
    test "inherits the parent's FKs and slots the parent by its type" do
      country = insert(:country, name_en: "Canada")

      subdivision1 =
        insert(:location,
          name_en: "Manitoba",
          location_type: :subdivision1,
          country: country
        )

      assert Location.level_fks_from_parent(subdivision1) == %{
               country_id: country.id,
               subdivision1_id: subdivision1.id,
               subdivision2_id: nil,
               city_id: nil,
               site_id: nil
             }
    end
  end

  describe "parent_id_from_levels/1" do
    test "is the deepest set level FK" do
      location = %Location{country_id: 1, subdivision1_id: 2, subdivision2_id: nil}
      assert Location.parent_id_from_levels(location) == 2
    end

    test "is nil for a top-level location" do
      assert Location.parent_id_from_levels(%Location{}) == nil
    end
  end

  describe "location_types/0 and hierarchy_levels/0" do
    test "hierarchy levels are the ordered set, top to bottom" do
      assert Location.hierarchy_levels() ==
               ~w(country subdivision1 subdivision2 city site section)a
    end

    test "location_types is the hierarchy plus special" do
      assert Location.location_types() ==
               ~w(country subdivision1 subdivision2 city site section special)a
    end
  end

  describe "level FK columns" do
    test "persist and load via their associations" do
      country = insert(:country, name_en: "Canada")

      subdivision1 =
        insert(:location,
          name_en: "Manitoba",
          location_type: "subdivision1",
          country: country
        )

      city =
        insert(:location,
          name_en: "Winnipeg",
          location_type: "city",
          country: country,
          subdivision1_id: subdivision1.id
        )

      site =
        insert(:location,
          name_en: "Assiniboine Park",
          location_type: "site",
          country: country,
          subdivision1_id: subdivision1.id,
          city_id: city.id
        )

      loaded =
        Repo.get!(Location, site.id)
        |> Repo.preload([:country, :subdivision1, :subdivision2, :city, :site])

      assert loaded.country.id == country.id
      assert loaded.subdivision1.id == subdivision1.id
      assert loaded.city.id == city.id
      assert is_nil(loaded.subdivision2)
      assert is_nil(loaded.site)
    end
  end

  describe "validate_slot_occupancy/1" do
    @level_fks Location.level_fks()

    defp slot_changeset(attrs) do
      Ecto.Changeset.cast(%Location{}, attrs, [:location_type | @level_fks])
      |> Location.validate_slot_occupancy()
    end

    test "valid when only ancestor slots above own level are set" do
      country = insert(:country)

      subdivision1 =
        insert(:location, location_type: "subdivision1", country: country)

      changeset =
        slot_changeset(%{
          location_type: "city",
          country_id: country.id,
          subdivision1_id: subdivision1.id
        })

      assert changeset.valid?
    end

    test "valid when an optional intermediate level is skipped" do
      country = insert(:country)

      subdivision1 =
        insert(:location, location_type: "subdivision1", country: country)

      # city hangs directly off subdivision1, skipping subdivision2
      changeset =
        slot_changeset(%{
          location_type: "city",
          country_id: country.id,
          subdivision1_id: subdivision1.id
        })

      assert changeset.valid?
    end

    test "valid when a city hangs directly off a country" do
      country = insert(:country)

      # country -> city -> site, skipping subdivision1/subdivision2
      changeset =
        slot_changeset(%{
          location_type: "city",
          country_id: country.id
        })

      assert changeset.valid?
    end

    test "valid for a top-level country with no slots set" do
      changeset = slot_changeset(%{location_type: "country"})
      assert changeset.valid?
    end

    test "special is exempt" do
      # no country_id, and a site_id that would be invalid for a hierarchy level
      changeset =
        slot_changeset(%{
          location_type: "special",
          site_id: insert(:location, location_type: "site").id
        })

      assert changeset.valid?
    end

    test "invalid with an FK at its own level" do
      country = insert(:country)
      sub = insert(:location, location_type: "subdivision1", country: country)

      changeset =
        slot_changeset(%{
          location_type: "subdivision1",
          country_id: country.id,
          subdivision1_id: sub.id
        })

      assert %{subdivision1_id: [_]} = errors_on(changeset)
    end

    test "invalid with an FK below its own level" do
      country = insert(:country)
      sub = insert(:location, location_type: "subdivision1", country: country)

      city =
        insert(:location, location_type: "city", country: country, subdivision1_id: sub.id)

      changeset =
        slot_changeset(%{
          location_type: "subdivision1",
          country_id: country.id,
          city_id: city.id
        })

      assert %{city_id: [_]} = errors_on(changeset)
    end

    test "invalid when a non-country location has no country" do
      # a city floating with no country_id
      changeset = slot_changeset(%{location_type: "city"})

      assert %{country_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid when an ancestor's higher-level FK is inconsistent" do
      country = insert(:country)
      other_country = insert(:country)

      # subdivision1 belongs to other_country, not country
      subdivision1 =
        insert(:location, location_type: "subdivision1", country: other_country)

      changeset =
        slot_changeset(%{
          location_type: "city",
          country_id: country.id,
          subdivision1_id: subdivision1.id
        })

      assert %{country_id: [_]} = errors_on(changeset)
    end
  end

  describe "long_name/2" do
    setup do
      country = insert(:country, name_en: "Canada")

      subdivision1 =
        insert(:location,
          name_en: "Manitoba",
          location_type: "subdivision1",
          country: country
        )

      city =
        insert(:location,
          name_en: "Winnipeg",
          location_type: "city",
          country: country,
          subdivision1_id: subdivision1.id
        )

      site =
        insert(:location,
          name_en: "Assiniboine Park",
          location_type: "site",
          country: country,
          subdivision1_id: subdivision1.id,
          city_id: city.id
        )

      %{country: country, subdivision1: subdivision1, city: city, site: site}
    end

    defp preload_levels(location) do
      Repo.preload(location, Location.Query.level_assocs())
    end

    test "composes own name then ancestors most-specific to country", %{site: site} do
      assert Location.long_name(:private, preload_levels(site)) ==
               "Assiniboine Park, Winnipeg, Manitoba, Canada"
    end

    test "skips unset intermediate levels", %{country: country} do
      # a city hanging directly off the country, no subdivision set
      city =
        insert(:location,
          name_en: "Lonely City",
          location_type: "city",
          country: country
        )

      assert Location.long_name(:private, preload_levels(city)) == "Lonely City, Canada"
    end

    test "a top-level country is just its own name", %{country: country} do
      assert Location.long_name(:private, preload_levels(country)) == "Canada"
    end

    test ":private includes private segments (owner-facing, no filtering)", %{
      country: country,
      subdivision1: subdivision1,
      city: city
    } do
      private_site =
        insert(:location,
          name_en: "Secret Patch",
          location_type: "site",
          is_private: true,
          country: country,
          subdivision1_id: subdivision1.id,
          city_id: city.id
        )

      assert Location.long_name(:private, preload_levels(private_site)) ==
               "Secret Patch, Winnipeg, Manitoba, Canada"
    end

    test ":public drops the location itself when it is private", %{
      country: country,
      subdivision1: subdivision1,
      city: city
    } do
      private_site =
        insert(:location,
          name_en: "Secret Patch",
          location_type: "site",
          is_private: true,
          country: country,
          subdivision1_id: subdivision1.id,
          city_id: city.id
        )

      assert Location.long_name(:public, preload_levels(private_site)) ==
               "Winnipeg, Manitoba, Canada"
    end

    test ":public drops a private ancestor from the chain", %{
      country: country,
      subdivision1: subdivision1
    } do
      private_city =
        insert(:location,
          name_en: "Hidden City",
          location_type: "city",
          is_private: true,
          country: country,
          subdivision1_id: subdivision1.id
        )

      site =
        insert(:location,
          name_en: "Open Patch",
          location_type: "site",
          country: country,
          subdivision1_id: subdivision1.id,
          city_id: private_city.id
        )

      assert Location.long_name(:public, preload_levels(site)) ==
               "Open Patch, Manitoba, Canada"
    end

    test ":public is empty when the location and all ancestors are private" do
      private_country =
        insert(:country, name_en: "Hidden Country", is_private: true)

      private_site =
        insert(:location,
          name_en: "Secret Patch",
          location_type: "site",
          is_private: true,
          country: private_country
        )

      assert Location.long_name(:public, preload_levels(private_site)) == ""
    end
  end

  describe "Query.for_user/2" do
    test "returns own and common locations but not another user's" do
      user = user_fixture()

      own = insert(:location, location_type: "city", user_id: user.id)
      common = insert(:location, location_type: "city")
      other = insert(:location, location_type: "city", user_id: user_fixture().id)

      ids = Location |> Query.for_user(user) |> Repo.all() |> Enum.map(& &1.id)

      assert own.id in ids
      assert common.id in ids
      refute other.id in ids
    end
  end

  describe "Query.child_locations/1" do
    defp child_location_ids(location) do
      location |> Query.child_locations() |> Repo.all() |> Enum.map(& &1.id) |> Enum.sort()
    end

    test "includes the location itself and descendants via its level FK" do
      country = insert(:country)
      subdivision = insert(:location, location_type: "subdivision1", country: country)

      city =
        insert(:location,
          location_type: "city",
          country: country,
          subdivision1_id: subdivision.id
        )

      assert child_location_ids(country) == Enum.sort([country.id, subdivision.id, city.id])
    end

    test "dispatches on the location's own level" do
      country = insert(:country)
      subdivision = insert(:location, location_type: "subdivision1", country: country)

      city =
        insert(:location,
          location_type: "city",
          country: country,
          subdivision1_id: subdivision.id
        )

      # descendants of the subdivision are matched by subdivision1_id, not the country
      assert child_location_ids(subdivision) == Enum.sort([subdivision.id, city.id])
    end

    test "a section (lowest level) has only itself" do
      country = insert(:country)

      section =
        insert(:location, location_type: "section", country: country)

      assert child_location_ids(section) == [section.id]
    end
  end

  describe "Query.direct_children/1" do
    defp direct_child_ids(location) do
      location |> Query.direct_children() |> Repo.all() |> Enum.map(& &1.id) |> Enum.sort()
    end

    test "returns only descendants whose deepest set FK is this location" do
      country = insert(:country)
      subdivision = insert(:location, location_type: "subdivision1", country: country)

      # A city nested under the subdivision is NOT a direct child of the country.
      _city =
        insert(:location,
          location_type: "city",
          country: country,
          subdivision1_id: subdivision.id
        )

      # A city hanging directly off the country IS a direct child.
      direct_city = insert(:location, location_type: "city", country: country)

      assert direct_child_ids(country) == Enum.sort([subdivision.id, direct_city.id])
    end

    test "excludes the location itself" do
      country = insert(:country)
      subdivision = insert(:location, location_type: "subdivision1", country: country)

      refute country.id in direct_child_ids(country)
      assert direct_child_ids(country) == [subdivision.id]
    end

    test "a section has no children" do
      country = insert(:country)
      section = insert(:location, location_type: "section", country: country)

      assert direct_child_ids(section) == []
    end
  end

  describe "Query.move_descendants/3" do
    test "re-points descendants from the old level column to the new one" do
      country = insert(:country)
      subdivision = insert(:location, location_type: "subdivision1", country: country)

      city =
        insert(:location,
          location_type: "city",
          country: country,
          subdivision1_id: subdivision.id
        )

      site =
        insert(:location,
          location_type: "site",
          country: country,
          subdivision1_id: subdivision.id,
          city_id: city.id
        )

      # subdivision demotes to subdivision2: descendants move subdivision1_id -> subdivision2_id.
      assert {2, _} =
               Query.move_descendants(subdivision.id, :subdivision1, :subdivision2)

      reloaded_city = Repo.get!(Location, city.id)
      assert reloaded_city.subdivision1_id == nil
      assert reloaded_city.subdivision2_id == subdivision.id
      assert reloaded_city.country_id == country.id

      reloaded_site = Repo.get!(Location, site.id)
      assert reloaded_site.subdivision1_id == nil
      assert reloaded_site.subdivision2_id == subdivision.id
      # The deeper city_id slot is untouched.
      assert reloaded_site.city_id == city.id
    end

    test "leaves unrelated locations alone" do
      country = insert(:country)
      subdivision = insert(:location, location_type: "subdivision1", country: country)
      other = insert(:location, location_type: "subdivision1", country: country)

      Query.move_descendants(subdivision.id, :subdivision1, :subdivision2)

      assert Repo.get!(Location, other.id).subdivision1_id == nil
      assert Repo.get!(Location, other.id).country_id == country.id
    end

    test "a move to/from section touches nothing" do
      country = insert(:country)
      section = insert(:location, location_type: "section", country: country)

      assert {0, nil} = Query.move_descendants(section.id, :section, :city)
    end
  end

  describe "Query.special_descendant_ids/1" do
    test "unions each member's descendants and the members themselves" do
      country = insert(:country)
      city = insert(:location, location_type: "city", country: country)
      site = insert(:location, location_type: "site", country: country, city_id: city.id)
      other = insert(:location, location_type: "city", country: country)

      special =
        insert(:special, special_child_locations: [city])

      ids = special |> Query.special_descendant_ids() |> Repo.all() |> Enum.sort()

      assert ids == Enum.sort([city.id, site.id])
      refute other.id in ids
    end

    test "is empty for a special with no members" do
      special = insert(:special)

      assert special |> Query.special_descendant_ids() |> Repo.all() == []
    end
  end

  describe "ancestor_ids/1" do
    test "returns the non-null level FK values, top to bottom" do
      country = insert(:country)
      subdivision = insert(:location, location_type: "subdivision1", country: country)

      site =
        insert(:location,
          location_type: "site",
          country: country,
          subdivision1_id: subdivision.id
        )

      assert Location.ancestor_ids(site) == [country.id, subdivision.id]
    end

    test "is empty for a top-level country" do
      country = insert(:country)
      assert Location.ancestor_ids(country) == []
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
end
