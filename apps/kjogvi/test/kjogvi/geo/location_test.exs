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
            ancestry: [],
            is_private: false
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
            ancestry: [],
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
      country = insert(:location, name_en: "Canada", location_type: "country")

      subdivision1 =
        insert(:location,
          name_en: "Manitoba",
          location_type: "subdivision1",
          country_id: country.id
        )

      city =
        insert(:location,
          name_en: "Winnipeg",
          location_type: "city",
          country_id: country.id,
          subdivision1_id: subdivision1.id
        )

      site =
        insert(:location,
          name_en: "Assiniboine Park",
          location_type: "site",
          country_id: country.id,
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
      country = insert(:location, location_type: "country")

      subdivision1 =
        insert(:location, location_type: "subdivision1", country_id: country.id)

      changeset =
        slot_changeset(%{
          location_type: "city",
          country_id: country.id,
          subdivision1_id: subdivision1.id
        })

      assert changeset.valid?
    end

    test "valid when an optional intermediate level is skipped" do
      country = insert(:location, location_type: "country")

      subdivision1 =
        insert(:location, location_type: "subdivision1", country_id: country.id)

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
      country = insert(:location, location_type: "country")

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
      country = insert(:location, location_type: "country")
      sub = insert(:location, location_type: "subdivision1", country_id: country.id)

      changeset =
        slot_changeset(%{
          location_type: "subdivision1",
          country_id: country.id,
          subdivision1_id: sub.id
        })

      assert %{subdivision1_id: [_]} = errors_on(changeset)
    end

    test "invalid with an FK below its own level" do
      country = insert(:location, location_type: "country")
      sub = insert(:location, location_type: "subdivision1", country_id: country.id)

      city =
        insert(:location, location_type: "city", country_id: country.id, subdivision1_id: sub.id)

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
      country = insert(:location, location_type: "country")
      other_country = insert(:location, location_type: "country")

      # subdivision1 belongs to other_country, not country
      subdivision1 =
        insert(:location, location_type: "subdivision1", country_id: other_country.id)

      changeset =
        slot_changeset(%{
          location_type: "city",
          country_id: country.id,
          subdivision1_id: subdivision1.id
        })

      assert %{country_id: [_]} = errors_on(changeset)
    end
  end

  describe "long_name_from_levels/1" do
    setup do
      country = insert(:location, name_en: "Canada", location_type: "country")

      subdivision1 =
        insert(:location,
          name_en: "Manitoba",
          location_type: "subdivision1",
          country_id: country.id
        )

      city =
        insert(:location,
          name_en: "Winnipeg",
          location_type: "city",
          country_id: country.id,
          subdivision1_id: subdivision1.id
        )

      site =
        insert(:location,
          name_en: "Assiniboine Park",
          location_type: "site",
          country_id: country.id,
          subdivision1_id: subdivision1.id,
          city_id: city.id
        )

      %{country: country, subdivision1: subdivision1, city: city, site: site}
    end

    defp preload_levels(location) do
      Repo.preload(location, Location.Query.level_assocs())
    end

    test "composes own name then ancestors most-specific to country", %{site: site} do
      assert site |> preload_levels() |> Location.long_name_from_levels() ==
               "Assiniboine Park, Winnipeg, Manitoba, Canada"
    end

    test "skips unset intermediate levels", %{country: country} do
      # a city hanging directly off the country, no subdivision set
      city =
        insert(:location,
          name_en: "Lonely City",
          location_type: "city",
          country_id: country.id
        )

      assert city |> preload_levels() |> Location.long_name_from_levels() ==
               "Lonely City, Canada"
    end

    test "a top-level country is just its own name", %{country: country} do
      assert country |> preload_levels() |> Location.long_name_from_levels() == "Canada"
    end

    test "drops the location itself when it is private", %{
      country: country,
      subdivision1: subdivision1,
      city: city
    } do
      private_site =
        insert(:location,
          name_en: "Secret Patch",
          location_type: "site",
          is_private: true,
          country_id: country.id,
          subdivision1_id: subdivision1.id,
          city_id: city.id
        )

      assert private_site |> preload_levels() |> Location.long_name_from_levels() ==
               "Winnipeg, Manitoba, Canada"
    end

    test "drops a private ancestor from the chain", %{
      country: country,
      subdivision1: subdivision1
    } do
      private_city =
        insert(:location,
          name_en: "Hidden City",
          location_type: "city",
          is_private: true,
          country_id: country.id,
          subdivision1_id: subdivision1.id
        )

      site =
        insert(:location,
          name_en: "Open Patch",
          location_type: "site",
          country_id: country.id,
          subdivision1_id: subdivision1.id,
          city_id: private_city.id
        )

      assert site |> preload_levels() |> Location.long_name_from_levels() ==
               "Open Patch, Manitoba, Canada"
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
