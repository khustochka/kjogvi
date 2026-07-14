defmodule Kjogvi.Geo.EbirdTest do
  use Kjogvi.DataCase, async: true

  alias Kjogvi.Geo.Ebird
  alias Kjogvi.Geo.EbirdLocation
  alias Kjogvi.Geo.Location
  alias Kjogvi.Repo

  defp reload(ebird_row), do: Repo.get!(EbirdLocation, ebird_row.id)

  describe "countries_with_statuses/0" do
    test "returns country rows ordered by code with their stats" do
      insert(:ebird_location, code: "CZ")
      country = insert(:country, iso_code: "AD")
      insert(:ebird_location, code: "AD", location_id: country.id)
      insert(:ebird_subdivision1, country_code: "AD", code: "AD-02")

      assert [
               %{ebird_location: %EbirdLocation{code: "AD"}, stats: %{status: :mixed}},
               %{ebird_location: %EbirdLocation{code: "CZ"}, stats: %{status: :ebird_only}}
             ] = Ebird.countries_with_statuses()
    end
  end

  describe "statuses_for_common_countries/1" do
    test "keys entries by location id for linked eBird countries" do
      country = insert(:country, iso_code: "AD")
      insert(:ebird_location, code: "AD", location_id: country.id)

      assert Ebird.statuses_for_common_countries([country]) ==
               %{country.id => %{code: "AD", status: :matched}}
    end

    test "falls back to the ISO code while the eBird country is unlinked" do
      country = insert(:country, iso_code: "CZ")
      insert(:ebird_location, code: "CZ")
      # A mismatched eBird subdivision keeps CZ's shape :mixed; without any
      # subdivisions it would be a trivially matched empty set.
      insert(:ebird_subdivision1, country_code: "CZ", code: "CZ-99", name: "No Match")

      assert Ebird.statuses_for_common_countries([country]) ==
               %{country.id => %{code: "CZ", status: :mixed}}
    end

    test "no ISO-code fallback to an eBird country linked elsewhere" do
      other = insert(:country, iso_code: "XX")
      insert(:ebird_location, code: "AD", location_id: other.id)
      country = insert(:country, iso_code: "AD")

      assert Ebird.statuses_for_common_countries([country]) == %{}
    end

    test "countries with no eBird counterpart and non-countries have no entry" do
      country = insert(:country, iso_code: "AD")
      insert(:ebird_location, code: "AD", location_id: country.id)
      no_ebird = insert(:country, iso_code: "BQ")
      subdivision1 = insert(:subdivision1, iso_code: "AD-02", country: country)

      assert Ebird.statuses_for_common_countries([country, no_ebird, subdivision1])
             |> Map.keys() == [country.id]
    end
  end

  describe "matchable_locations/1" do
    test "returns the country and subdivision1 rows ordered by code, sub2s excluded" do
      insert(:ebird_location, code: "AD")
      insert(:ebird_subdivision1, country_code: "AD", code: "AD-03")
      insert(:ebird_subdivision1, country_code: "AD", code: "AD-02")

      insert(:ebird_location,
        code: "AD-02-X",
        location_type: :subdivision2,
        country_code: "AD",
        subnational2_code: "AD-02-X"
      )

      insert(:ebird_location, code: "XY")

      assert ["AD", "AD-02", "AD-03"] =
               Enum.map(Ebird.matchable_locations("AD"), & &1.code)
    end

    test "preloads the linked location" do
      country = insert(:country, iso_code: "AD")
      insert(:ebird_location, code: "AD", location_id: country.id)

      assert [%EbirdLocation{location: %Location{iso_code: "AD"}}] =
               Ebird.matchable_locations("AD")
    end
  end

  describe "unmatched_iso_subdivision1s/1" do
    test "lists the linked country's subdivisions no eBird row points at" do
      country = insert(:country, iso_code: "HU")
      linked = insert(:subdivision1, iso_code: "HU-BU", country: country)
      extra = insert(:subdivision1, iso_code: "HU-BA", name_en: "Baranya", country: country)

      insert(:ebird_location, code: "HU", location_id: country.id)
      insert(:ebird_subdivision1, country_code: "HU", code: "HU-BU", location_id: linked.id)

      assert [%Location{id: extra_id}] = Ebird.unmatched_iso_subdivision1s("HU")
      assert extra_id == extra.id
    end

    test "empty when the eBird country row is not linked" do
      country = insert(:country, iso_code: "HU")
      insert(:subdivision1, iso_code: "HU-BA", country: country)
      insert(:ebird_location, code: "HU")

      assert Ebird.unmatched_iso_subdivision1s("HU") == []
    end
  end

  describe "link/2" do
    test "links an unlinked region to a common location" do
      country = insert(:country, iso_code: "AD")
      ebird_country = insert(:ebird_location, code: "AD")

      assert {:ok, %EbirdLocation{location_id: location_id}} =
               Ebird.link(ebird_country, country.id)

      assert location_id == country.id
    end

    test "refuses a user-owned location" do
      location = insert(:location, user_id: Kjogvi.AccountsFixtures.user_fixture().id)
      ebird_country = insert(:ebird_location, code: "AD")

      assert Ebird.link(ebird_country, location.id) == {:error, :not_common}
      assert reload(ebird_country).location_id == nil
    end

    test "refuses an unknown location id" do
      ebird_country = insert(:ebird_location, code: "AD")

      assert Ebird.link(ebird_country, -1) == {:error, :not_found}
    end

    test "refuses an already linked region, even from a stale struct" do
      country = insert(:country, iso_code: "AD")
      other = insert(:country, iso_code: "XY")
      ebird_country = insert(:ebird_location, code: "AD")

      {:ok, _} = Ebird.link(ebird_country, country.id)

      # `ebird_country` is now stale — it still carries `location_id: nil`.
      assert Ebird.link(ebird_country, other.id) == {:error, :already_linked}
      assert reload(ebird_country).location_id == country.id
    end

    test "a location linked from another eBird row is rejected by the unique constraint" do
      country = insert(:country, iso_code: "AD")
      insert(:ebird_location, code: "AD", location_id: country.id)
      other_row = insert(:ebird_location, code: "XY")

      assert {:error, %Ecto.Changeset{errors: errors}} = Ebird.link(other_row, country.id)
      assert Keyword.has_key?(errors, :location_id)
    end
  end

  describe "unlink/1" do
    test "clears the link" do
      country = insert(:country, iso_code: "AD")
      ebird_country = insert(:ebird_location, code: "AD", location_id: country.id)

      assert {:ok, %EbirdLocation{location_id: nil}} = Ebird.unlink(ebird_country)
      assert reload(ebird_country).location_id == nil
    end
  end

  describe "create_common_location/1" do
    test "creates and links a common country from an eBird-only country row" do
      ebird_country = insert(:ebird_location, code: "XK", name: "Kosovo")

      assert {:ok, %Location{} = location} = Ebird.create_common_location(ebird_country)

      assert location.slug == "xk"
      assert location.name_en == "Kosovo"
      assert location.location_type == :country
      assert location.user_id == nil
      assert location.iso_code == nil
      assert location.import_source == :ebird_regions
      assert reload(ebird_country).location_id == location.id
    end

    test "creates a subdivision1 under the linked common country" do
      country = insert(:country, iso_code: "AZ")
      insert(:ebird_location, code: "AZ", location_id: country.id)

      ebird_sub1 =
        insert(:ebird_subdivision1, country_code: "AZ", code: "AZ-KAL", name: "Kalbajar")

      assert {:ok, %Location{} = location} = Ebird.create_common_location(ebird_sub1)

      assert location.slug == "az_kal"
      assert location.location_type == :subdivision1
      assert location.country_id == country.id
      assert reload(ebird_sub1).location_id == location.id
    end

    test "refuses a subdivision1 whose eBird country row is not linked" do
      insert(:ebird_location, code: "XK")
      ebird_sub1 = insert(:ebird_subdivision1, country_code: "XK", code: "XK-01")

      assert Ebird.create_common_location(ebird_sub1) == {:error, :country_not_linked}
    end

    test "refuses an already linked region" do
      country = insert(:country, iso_code: "AD")
      ebird_country = insert(:ebird_location, code: "AD", location_id: country.id)

      assert Ebird.create_common_location(ebird_country) == {:error, :already_linked}
    end

    test "a slug collision returns the changeset and links nothing" do
      insert(:country, slug: "xk", iso_code: "XY")
      ebird_country = insert(:ebird_location, code: "XK")

      assert {:error, %Ecto.Changeset{errors: errors}} =
               Ebird.create_common_location(ebird_country)

      assert Keyword.has_key?(errors, :slug)
      assert reload(ebird_country).location_id == nil
    end
  end
end
