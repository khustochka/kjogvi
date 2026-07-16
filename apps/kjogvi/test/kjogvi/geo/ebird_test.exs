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

      # AD: eBird subdivides it, ISO has no subdivisions. CZ: no ISO country.
      assert [
               %{
                 ebird_location: %EbirdLocation{code: "AD"},
                 stats: %{status: :ebird_only_subregions}
               },
               %{ebird_location: %EbirdLocation{code: "CZ"}, stats: %{status: :ebird_only}}
             ] = Ebird.countries_with_statuses()
    end

    test "a disabled ISO country is no counterpart: the eBird row reads :ebird_only" do
      insert(:country, iso_code: "PR", disabled: true)
      insert(:ebird_location, code: "PR")

      assert [%{ebird_location: %EbirdLocation{code: "PR"}, stats: %{status: :ebird_only}}] =
               Ebird.countries_with_statuses()
    end

    test "disabled subdivisions drop out of the ISO side of the shape" do
      country = insert(:country, iso_code: "AD")
      insert(:subdivision1, iso_code: "AD-02", country: country)
      insert(:subdivision1, iso_code: "AD-03", country: country, disabled: true)
      insert(:ebird_location, code: "AD", location_id: country.id)
      insert(:ebird_subdivision1, country_code: "AD", code: "AD-02")

      # Without the disabled AD-03 the code sets are equal — :matched, not :iso_extra.
      assert [%{stats: %{status: :matched, iso_extra: 0}}] = Ebird.countries_with_statuses()
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
      # Both sides subdivide but agree on neither code nor name, so CZ's shape is
      # :mixed; without any subdivisions it would be a trivially matched empty set.
      insert(:subdivision1, iso_code: "CZ-10", name_en: "Praha", country: country)
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

  describe "subdivision1_comparison/1" do
    test "pairs linked rows and lists each side's leftovers" do
      country = insert(:country, iso_code: "HU")
      linked = insert(:subdivision1, iso_code: "HU-BU", name_en: "Budapest", country: country)
      iso_only = insert(:subdivision1, iso_code: "HU-BA", name_en: "Baranya", country: country)

      insert(:ebird_location, code: "HU", location_id: country.id)

      ebird_linked =
        insert(:ebird_subdivision1, country_code: "HU", code: "HU-BU", location_id: linked.id)

      ebird_only =
        insert(:ebird_subdivision1, country_code: "HU", code: "HU-ZZ", name: "High Seas")

      assert [baranya, budapest, seas] = Ebird.subdivision1_comparison("HU")

      assert %{ebird: nil, pairing: :iso_only} = baranya
      assert baranya.location.id == iso_only.id

      assert %{pairing: :linked} = budapest
      assert budapest.ebird.id == ebird_linked.id
      assert budapest.location.id == linked.id

      assert %{location: nil, pairing: :ebird_only} = seas
      assert seas.ebird.id == ebird_only.id
    end

    test "suggests an unlinked pair by code even when the names differ" do
      country = insert(:country, iso_code: "BA")

      federacija =
        insert(:subdivision1,
          iso_code: "BA-BIH",
          name_en: "Federacija Bosne i Hercegovine",
          country: country
        )

      insert(:ebird_location, code: "BA", location_id: country.id)

      ebird =
        insert(:ebird_subdivision1,
          country_code: "BA",
          code: "BA-BIH",
          name: "Federacija Bosna i Hercegovina"
        )

      assert [row] = Ebird.subdivision1_comparison("BA")
      assert %{pairing: :code_suggestion} = row
      assert row.ebird.id == ebird.id
      assert row.location.id == federacija.id
    end

    test "prefers the code pairing over a competing name pairing" do
      country = insert(:country, iso_code: "BA")
      by_code = insert(:subdivision1, iso_code: "BA-BIH", name_en: "Republika", country: country)
      by_name = insert(:subdivision1, iso_code: "BA-XX", name_en: "Federacija", country: country)
      insert(:ebird_location, code: "BA", location_id: country.id)

      ebird =
        insert(:ebird_subdivision1, country_code: "BA", code: "BA-BIH", name: "Federacija")

      rows = Ebird.subdivision1_comparison("BA")

      assert [%{ebird: %{id: ebird_id}, location: %{id: location_id}, pairing: :code_suggestion}] =
               Enum.filter(rows, &(&1.pairing == :code_suggestion))

      assert ebird_id == ebird.id
      assert location_id == by_code.id

      # The name-matching location is left over rather than stealing the row.
      assert [%{location: %{id: leftover_id}}] = Enum.filter(rows, &(&1.pairing == :iso_only))
      assert leftover_id == by_name.id
    end

    test "suggests unlinked pairs whose normalized names match" do
      country = insert(:country, iso_code: "PL")
      lodzkie = insert(:subdivision1, iso_code: "PL-LD", name_en: "Łódzkie", country: country)
      insert(:ebird_location, code: "PL", location_id: country.id)
      ebird = insert(:ebird_subdivision1, country_code: "PL", code: "PL-91", name: "Lodzkie")

      assert [row] = Ebird.subdivision1_comparison("PL")
      assert %{pairing: :name_suggestion} = row
      assert row.ebird.id == ebird.id
      assert row.location.id == lodzkie.id
    end

    test "leaves an ambiguous name unpaired on both sides" do
      country = insert(:country, iso_code: "PL")
      insert(:subdivision1, iso_code: "PL-LD", name_en: "Lodzkie", country: country)
      insert(:subdivision1, iso_code: "PL-XX", name_en: "Lodzkie", country: country)
      insert(:ebird_location, code: "PL", location_id: country.id)
      insert(:ebird_subdivision1, country_code: "PL", code: "PL-91", name: "Lodzkie")

      rows = Ebird.subdivision1_comparison("PL")

      assert Enum.map(rows, & &1.pairing) == [:ebird_only, :iso_only, :iso_only]
    end

    test "omits a subdivision linked from another country's eBird row" do
      country = insert(:country, iso_code: "HU")
      sub1 = insert(:subdivision1, iso_code: "HU-BU", name_en: "Budapest", country: country)
      insert(:ebird_location, code: "HU", location_id: country.id)
      # Linked from an eBird row that is not among HU's subdivisions.
      insert(:ebird_subdivision1, country_code: "XX", code: "XX-01", location_id: sub1.id)

      assert Ebird.subdivision1_comparison("HU") == []
    end

    test "populates the ISO side before the country row is linked" do
      country = insert(:country, iso_code: "AD")
      sub1 = insert(:subdivision1, iso_code: "AD-02", name_en: "Canillo", country: country)
      insert(:ebird_location, code: "AD")

      assert [row] = Ebird.subdivision1_comparison("AD")
      assert %{ebird: nil, pairing: :iso_only} = row
      assert row.location.id == sub1.id
    end

    test "omits a disabled subdivision from the ISO side, leaving its eBird row alone" do
      country = insert(:country, iso_code: "AD")

      insert(:subdivision1,
        iso_code: "AD-02",
        name_en: "Canillo",
        country: country,
        disabled: true
      )

      insert(:ebird_location, code: "AD", location_id: country.id)
      ebird_sub1 = insert(:ebird_subdivision1, country_code: "AD", code: "AD-02", name: "Canillo")

      # No :code_suggestion — the pass would not link it, so the view must not offer it.
      assert [%{location: nil, pairing: :ebird_only} = row] = Ebird.subdivision1_comparison("AD")
      assert row.ebird.id == ebird_sub1.id
    end

    test "reaches the ISO side through the link for an eBird-only country" do
      country = insert(:country, iso_code: nil, slug: "xk")
      sub1 = insert(:subdivision1, iso_code: "XK-01", name_en: "Pristina", country: country)
      insert(:ebird_location, code: "XK", location_id: country.id)

      assert [row] = Ebird.subdivision1_comparison("XK")
      assert row.location.id == sub1.id
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
      assert location.iso_code == "XK"
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
      assert location.iso_code == "AZ-KAL"
      assert location.location_type == :subdivision1
      assert location.country_id == country.id
      assert reload(ebird_sub1).location_id == location.id
    end

    test "an iso_code collision returns the changeset and links nothing" do
      insert(:country, slug: "other", iso_code: "XK")
      ebird_country = insert(:ebird_location, code: "XK")

      assert {:error, %Ecto.Changeset{errors: errors}} =
               Ebird.create_common_location(ebird_country)

      assert Keyword.has_key?(errors, :iso_code)
      assert reload(ebird_country).location_id == nil
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

  describe "create_all_common_locations/1" do
    test "creates and links every unlinked subdivision1" do
      country = insert(:country, iso_code: "PR", name_en: "Puerto Rico")
      insert(:ebird_location, code: "PR", location_id: country.id)
      adjuntas = insert(:ebird_subdivision1, country_code: "PR", code: "PR-001", name: "Adjuntas")
      aguada = insert(:ebird_subdivision1, country_code: "PR", code: "PR-003", name: "Aguada")

      assert Ebird.create_all_common_locations("PR") == %{created: 2, failed: 0}

      for region <- [adjuntas, aguada] do
        location = Repo.get!(Location, reload(region).location_id)
        assert location.location_type == :subdivision1
        assert location.country_id == country.id
        assert location.import_source == :ebird_regions
      end
    end

    test "leaves already linked rows alone and skips other countries" do
      country = insert(:country, iso_code: "PR")
      insert(:ebird_location, code: "PR", location_id: country.id)
      existing = insert(:subdivision1, country: country, name_en: "Adjuntas")

      linked =
        insert(:ebird_subdivision1, country_code: "PR", code: "PR-001", location_id: existing.id)

      other = insert(:ebird_subdivision1, country_code: "AD", code: "AD-02")

      assert Ebird.create_all_common_locations("PR") == %{created: 0, failed: 0}

      assert reload(linked).location_id == existing.id
      assert reload(other).location_id == nil
    end

    test "a slug collision fails only its own row" do
      country = insert(:country, iso_code: "PR")
      insert(:ebird_location, code: "PR", location_id: country.id)
      insert(:country, slug: "pr_001", iso_code: "XY")
      colliding = insert(:ebird_subdivision1, country_code: "PR", code: "PR-001")
      ok = insert(:ebird_subdivision1, country_code: "PR", code: "PR-003")

      assert Ebird.create_all_common_locations("PR") == %{created: 1, failed: 1}

      assert reload(colliding).location_id == nil
      assert reload(ok).location_id != nil
    end

    test "reports nothing to do when the country row is unlinked" do
      insert(:ebird_location, code: "PR")
      region = insert(:ebird_subdivision1, country_code: "PR", code: "PR-001")

      assert Ebird.create_all_common_locations("PR") == %{created: 0, failed: 1}
      assert reload(region).location_id == nil
    end
  end

  describe "country_statuses/0 subdivision2 counts" do
    test "carries the country's sub2 totals and imported counts" do
      country = insert(:country, iso_code: "US")
      subdivision = insert(:subdivision1, iso_code: "US-CA", country: country)
      insert(:ebird_location, code: "US", location_id: country.id)
      insert(:ebird_subdivision1, country_code: "US", code: "US-CA", location_id: subdivision.id)

      imported = insert(:location, country: country, location_type: :subdivision2)
      insert(:ebird_subdivision2, subnational1_code: "US-CA", location_id: imported.id)
      insert(:ebird_subdivision2, subnational1_code: "US-CA")

      assert %{"US" => %{sub2_total: 2, sub2_linked: 1}} = Ebird.country_statuses()
    end

    test "defaults to zero for countries without subdivision2 rows" do
      insert(:ebird_location, code: "AD")

      assert %{"AD" => %{sub2_total: 0, sub2_linked: 0}} = Ebird.country_statuses()
    end
  end

  describe "sub2_stats_by_sub1/1" do
    test "groups the country's sub2 progress by subdivision1 code" do
      country = insert(:country, iso_code: "US")
      imported = insert(:location, country: country, location_type: :subdivision2)
      insert(:ebird_subdivision2, subnational1_code: "US-CA", location_id: imported.id)
      insert(:ebird_subdivision2, subnational1_code: "US-CA")
      insert(:ebird_subdivision2, subnational1_code: "US-NY")
      insert(:ebird_subdivision2, subnational1_code: "CA-AB")

      assert Ebird.sub2_stats_by_sub1("US") == %{
               "US-CA" => %{total: 2, linked: 1},
               "US-NY" => %{total: 1, linked: 0}
             }
    end
  end

  describe "import_subdivision2s/1" do
    test "creates each sub2 under its linked subdivision1" do
      country = insert(:country, iso_code: "US")
      california = insert(:subdivision1, iso_code: "US-CA", country: country)
      insert(:ebird_location, code: "US", location_id: country.id)

      insert(:ebird_subdivision1,
        country_code: "US",
        code: "US-CA",
        location_id: california.id
      )

      alameda =
        insert(:ebird_subdivision2,
          subnational1_code: "US-CA",
          code: "US-CA-001",
          name: "Alameda"
        )

      assert Ebird.import_subdivision2s("US") == %{created: 1, failed: 0}

      location = Repo.get!(Location, reload(alameda).location_id)
      assert location.location_type == :subdivision2
      assert location.name_en == "Alameda"
      assert location.slug == "us_ca_001"
      assert location.iso_code == "US-CA-001"
      assert location.import_source == :ebird_regions
      assert location.country_id == country.id
      assert location.subdivision1_id == california.id
      assert location.user_id == nil
    end

    test "fails rows whose subdivision1 is not linked, leaving the rest done" do
      country = insert(:country, iso_code: "US")
      california = insert(:subdivision1, iso_code: "US-CA", country: country)

      insert(:ebird_subdivision1,
        country_code: "US",
        code: "US-CA",
        location_id: california.id
      )

      insert(:ebird_subdivision1, country_code: "US", code: "US-NY")
      ok = insert(:ebird_subdivision2, subnational1_code: "US-CA", code: "US-CA-001")
      orphan = insert(:ebird_subdivision2, subnational1_code: "US-NY", code: "US-NY-001")

      assert Ebird.import_subdivision2s("US") == %{created: 1, failed: 1}

      assert reload(ok).location_id != nil
      assert reload(orphan).location_id == nil
    end

    test "leaves already imported rows alone and skips other countries" do
      country = insert(:country, iso_code: "US")
      california = insert(:subdivision1, iso_code: "US-CA", country: country)

      insert(:ebird_subdivision1,
        country_code: "US",
        code: "US-CA",
        location_id: california.id
      )

      existing = insert(:location, country: country, location_type: :subdivision2)

      imported =
        insert(:ebird_subdivision2,
          subnational1_code: "US-CA",
          code: "US-CA-001",
          location_id: existing.id
        )

      other = insert(:ebird_subdivision2, subnational1_code: "CA-AB", code: "CA-AB-EI")

      assert Ebird.import_subdivision2s("US") == %{created: 0, failed: 0}

      assert reload(imported).location_id == existing.id
      assert reload(other).location_id == nil
    end

    test "a slug collision fails only its own row" do
      country = insert(:country, iso_code: "US")
      california = insert(:subdivision1, iso_code: "US-CA", country: country)

      insert(:ebird_subdivision1,
        country_code: "US",
        code: "US-CA",
        location_id: california.id
      )

      insert(:country, slug: "us_ca_001", iso_code: "XY")
      colliding = insert(:ebird_subdivision2, subnational1_code: "US-CA", code: "US-CA-001")
      ok = insert(:ebird_subdivision2, subnational1_code: "US-CA", code: "US-CA-003")

      assert Ebird.import_subdivision2s("US") == %{created: 1, failed: 1}

      assert reload(colliding).location_id == nil
      assert reload(ok).location_id != nil
    end
  end
end
