defmodule Kjogvi.Birding.LogTest do
  use Kjogvi.DataCase, async: true

  import Kjogvi.UsersFixtures

  alias Kjogvi.Birding.Log
  alias Kjogvi.Birding.Lifelist
  alias Kjogvi.Factory
  alias Kjogvi.GeoFixtures

  # Build a scope for a given user
  defp scope(user), do: %Lifelist.Scope{user: user, include_private: false}

  # Persist log_settings on the user through the real changeset path.
  defp put_log_settings(user, settings) do
    {:ok, user} =
      Kjogvi.Users.update_user_settings(user, %{extras: %{log_settings: settings}})

    user
  end

  # Build log_settings attrs that enable life+year for World and a list of locations
  defp all_enabled_settings(locations) do
    world = %{location_id: nil, life: true, year: true}
    location_settings = Enum.map(locations, &%{location_id: &1.id, life: true, year: true})
    [world | location_settings]
  end

  # Create a country and optionally a subdivision under it (with public_index set)
  defp insert_country(name, public_index \\ 1) do
    GeoFixtures.location_fixture(%{
      name_en: name,
      location_type: "country",
      ancestry: [],
      public_index: public_index
    })
  end

  defp insert_subdivision(name, country, public_index \\ 10) do
    GeoFixtures.location_fixture(%{
      name_en: name,
      location_type: "region",
      ancestry: [country.id],
      public_index: public_index,
      cached_country_id: country.id
    })
  end

  defp insert_site(country, subdivision \\ nil) do
    ancestry =
      if subdivision, do: [country.id, subdivision.id], else: [country.id]

    GeoFixtures.location_fixture(%{
      name_en: "Some Site",
      location_type: "site",
      ancestry: ancestry
    })
  end

  defp card(user, date, location) do
    insert(:card, observ_date: date, user: user, location: location)
  end

  defp obs(card, taxon_key) do
    insert(:observation, card: card, taxon_key: taxon_key)
  end

  describe "recent_entries/2" do
    test "returns empty list when no observations" do
      user = user_fixture()
      assert Log.recent_entries(scope(user)) == []
    end

    test "returns a lifer entry for a new world species" do
      user = user_fixture()
      {taxon, _page} = Factory.create_species_taxon_with_page()
      country = insert_country("Canada")
      site = insert_site(country)

      today = Date.utc_today()
      c = card(user, today, site)
      obs(c, Ornitho.Schema.Taxon.key(taxon))

      entries = Log.recent_entries(scope(user))
      assert length(entries) == 1

      {date, day_entries} = hd(entries)
      assert date == today

      lifer_entry = Enum.find(day_entries, &(&1.type == :life && is_nil(&1.area)))
      assert lifer_entry != nil
      assert length(lifer_entry.life_observations) == 1
    end

    test "a lifer suppresses country, subdivision, and year entries" do
      user = user_fixture()
      {taxon, _page} = Factory.create_species_taxon_with_page()
      country = insert_country("Canada")
      subdivision = insert_subdivision("Manitoba", country)
      site = insert_site(country, subdivision)

      today = Date.utc_today()
      c = card(user, today, site)
      obs(c, Ornitho.Schema.Taxon.key(taxon))

      entries = Log.recent_entries(scope(user))
      {_date, day_entries} = hd(entries)

      # Only the world lifer entry should appear (total for nil area)
      total_entries = Enum.filter(day_entries, &(&1.type == :life))
      assert length(total_entries) == 1
      assert hd(total_entries).area == nil

      # World year entry should also be suppressed (lifer covers it)
      refute Enum.any?(day_entries, &(&1.type == :year && is_nil(&1.area)))
    end

    test "country total is shown when species is not a world lifer" do
      {taxon, _page} = Factory.create_species_taxon_with_page()
      country_ca = insert_country("Canada", 1)
      country_ua = insert_country("Ukraine", 2)
      site_ca = insert_site(country_ca)
      site_ua = insert_site(country_ua)

      user =
        user_fixture()
        |> put_log_settings(all_enabled_settings([country_ca, country_ua]))

      # Saw species in Ukraine first (so not a world lifer when seeing in Canada)
      yesterday = Date.add(Date.utc_today(), -1)
      today = Date.utc_today()

      c1 = card(user, yesterday, site_ua)
      obs(c1, Ornitho.Schema.Taxon.key(taxon))

      c2 = card(user, today, site_ca)
      obs(c2, Ornitho.Schema.Taxon.key(taxon))

      entries = Log.recent_entries(scope(user))
      today_entry = Enum.find(entries, fn {date, _} -> date == today end)
      assert today_entry != nil

      {_date, day_entries} = today_entry

      # Should show Canada total (not a world lifer, but new for Canada)
      ca_total =
        Enum.find(day_entries, &(&1.type == :life && &1.area && &1.area.id == country_ca.id))

      assert ca_total != nil

      # Should NOT show world total (it was seen in Ukraine yesterday)
      world_total = Enum.find(day_entries, &(&1.type == :life && is_nil(&1.area)))
      assert world_total == nil
    end

    test "year entry is shown when species is not new to the year list" do
      user = user_fixture()
      {taxon, _page} = Factory.create_species_taxon_with_page()
      country = insert_country("Canada")
      site = insert_site(country)

      # Saw species last year
      last_year_date = ~D[2025-06-15]
      c1 = card(user, last_year_date, site)
      obs(c1, Ornitho.Schema.Taxon.key(taxon))

      # Saw again this year (new year bird, but not a lifer)
      this_year_date = Date.utc_today()
      c2 = card(user, this_year_date, site)
      obs(c2, Ornitho.Schema.Taxon.key(taxon))

      entries = Log.recent_entries(scope(user))
      today_entry = Enum.find(entries, fn {date, _} -> date == this_year_date end)
      assert today_entry != nil

      {_date, day_entries} = today_entry

      # Should have a year entry for world (nil area), not a total
      year_entry = Enum.find(day_entries, &(&1.type == :year && is_nil(&1.area)))
      assert year_entry != nil
      assert year_entry.year == this_year_date.year

      # Should NOT show a total entry (not a lifer)
      world_total = Enum.find(day_entries, &(&1.type == :life && is_nil(&1.area)))
      assert world_total == nil
    end

    test "multiple species added on same day are grouped into one entry per area/type" do
      user = user_fixture()
      {taxon1, _} = Factory.create_species_taxon_with_page()
      {taxon2, _} = Factory.create_species_taxon_with_page()
      country = insert_country("Canada")
      site = insert_site(country)

      today = Date.utc_today()
      c = card(user, today, site)
      obs(c, Ornitho.Schema.Taxon.key(taxon1))
      obs(c, Ornitho.Schema.Taxon.key(taxon2))

      entries = Log.recent_entries(scope(user))
      {_date, day_entries} = hd(entries)

      lifer_entry = Enum.find(day_entries, &(&1.type == :life && is_nil(&1.area)))
      assert lifer_entry != nil
      assert length(lifer_entry.life_observations) == 2
    end

    test "respects the limit option" do
      user = user_fixture()
      country = insert_country("Canada")
      site = insert_site(country)

      # Create observations of different species on 3 different dates so each
      # date produces at least one new entry.
      for i <- 0..2 do
        {taxon, _} = Factory.create_species_taxon_with_page()
        d = Date.add(Date.utc_today(), -i)
        c = card(user, d, site)
        obs(c, Ornitho.Schema.Taxon.key(taxon))
      end

      entries = Log.recent_entries(scope(user), limit: 2)
      assert length(entries) == 2
    end

    test "list_total reflects cumulative species count for the list" do
      user = user_fixture()
      {taxon1, _} = Factory.create_species_taxon_with_page()
      {taxon2, _} = Factory.create_species_taxon_with_page()
      country = insert_country("Canada")
      site = insert_site(country)

      yesterday = Date.add(Date.utc_today(), -1)
      today = Date.utc_today()

      # First species yesterday
      c1 = card(user, yesterday, site)
      obs(c1, Ornitho.Schema.Taxon.key(taxon1))

      # Second species today
      c2 = card(user, today, site)
      obs(c2, Ornitho.Schema.Taxon.key(taxon2))

      entries = Log.recent_entries(scope(user))

      # Today's world lifer entry should show list_total = 2
      {_date, today_entries} =
        Enum.find(entries, fn {date, _} -> date == today end)

      lifer_entry = Enum.find(today_entries, &(&1.type == :life && is_nil(&1.area)))
      assert lifer_entry.list_total == 2

      # Yesterday's world lifer entry should show list_total = 1
      {_date, yesterday_entries} =
        Enum.find(entries, fn {date, _} -> date == yesterday end)

      yesterday_lifer = Enum.find(yesterday_entries, &(&1.type == :life && is_nil(&1.area)))
      assert yesterday_lifer.list_total == 1
    end

    test "respects the cutoff_days option" do
      user = user_fixture()
      {taxon, _} = Factory.create_species_taxon_with_page()
      country = insert_country("Canada")
      site = insert_site(country)

      old_date = Date.add(Date.utc_today(), -10)
      c = card(user, old_date, site)
      obs(c, Ornitho.Schema.Taxon.key(taxon))

      # Only look back 5 days — should find nothing
      entries = Log.recent_entries(scope(user), cutoff_days: 5)
      assert entries == []
    end

    test "log_settings can disable world life entries" do
      {taxon, _page} = Factory.create_species_taxon_with_page()
      country_ca = insert_country("Canada", 1)
      country_ua = insert_country("Ukraine", 2)
      site_ca = insert_site(country_ca)
      site_ua = insert_site(country_ua)

      # Disable world life, keep country life
      settings = [
        %{location_id: nil, life: false, year: true},
        %{location_id: country_ca.id, life: true, year: true},
        %{location_id: country_ua.id, life: true, year: true}
      ]

      user = user_fixture() |> put_log_settings(settings)

      # Saw species in Ukraine first (world lifer yesterday)
      yesterday = Date.add(Date.utc_today(), -1)
      today = Date.utc_today()

      c1 = card(user, yesterday, site_ua)
      obs(c1, Ornitho.Schema.Taxon.key(taxon))

      # Saw in Canada today (new for Canada, not a world lifer)
      c2 = card(user, today, site_ca)
      obs(c2, Ornitho.Schema.Taxon.key(taxon))

      entries = Log.recent_entries(scope(user))

      # Yesterday's world lifer should be filtered out
      yesterday_entry = Enum.find(entries, fn {date, _} -> date == yesterday end)

      if yesterday_entry do
        {_date, day_entries} = yesterday_entry
        refute Enum.any?(day_entries, &(&1.type == :life && is_nil(&1.area)))
      end

      # Today's Canada lifer should appear
      today_entry = Enum.find(entries, fn {date, _} -> date == today end)
      assert today_entry != nil
      {_date, today_entries} = today_entry

      assert Enum.any?(
               today_entries,
               &(&1.type == :life && &1.area && &1.area.id == country_ca.id)
             )
    end

    test "log_settings can disable a specific location" do
      {taxon, _page} = Factory.create_species_taxon_with_page()
      country_ca = insert_country("Canada", 1)
      country_ua = insert_country("Ukraine", 2)
      site_ca = insert_site(country_ca)
      site_ua = insert_site(country_ua)

      # Disable Canada entries
      settings = [%{location_id: country_ca.id, life: false, year: false}]
      user = user_fixture() |> put_log_settings(settings)

      yesterday = Date.add(Date.utc_today(), -1)
      today = Date.utc_today()

      c1 = card(user, yesterday, site_ua)
      obs(c1, Ornitho.Schema.Taxon.key(taxon))

      c2 = card(user, today, site_ca)
      obs(c2, Ornitho.Schema.Taxon.key(taxon))

      entries = Log.recent_entries(scope(user))
      today_entry = Enum.find(entries, fn {date, _} -> date == today end)

      # Canada entry should not appear
      if today_entry do
        {_date, day_entries} = today_entry
        refute Enum.any?(day_entries, &(&1.area && &1.area.id == country_ca.id))
      end
    end

    test "world lifer annotates covered country and subdivision when enabled in settings" do
      {taxon, _page} = Factory.create_species_taxon_with_page()
      country = insert_country("Canada")
      subdivision = insert_subdivision("Manitoba", country)
      site = insert_site(country, subdivision)

      user =
        user_fixture()
        |> put_log_settings(all_enabled_settings([country, subdivision]))

      today = Date.utc_today()
      c = card(user, today, site)
      obs(c, Ornitho.Schema.Taxon.key(taxon))

      entries = Log.recent_entries(scope(user))
      {_date, day_entries} = hd(entries)

      lifer_entry = Enum.find(day_entries, &(&1.type == :life && is_nil(&1.area)))
      assert lifer_entry != nil

      covered_ids = Enum.map(lifer_entry.covered_areas, fn {area, _} -> area.id end)
      assert country.id in covered_ids
      assert subdivision.id in covered_ids

      # covered list_totals match the life totals for each area (1 for each)
      for {_area, total} <- lifer_entry.covered_areas do
        assert total == 1
      end

      # Canada/Manitoba should NOT appear as standalone entries
      refute Enum.any?(day_entries, &(&1.type == :life && &1.area && &1.area.id == country.id))

      refute Enum.any?(
               day_entries,
               &(&1.type == :life && &1.area && &1.area.id == subdivision.id)
             )
    end

    test "covered_areas is empty when area is not enabled in log_settings" do
      {taxon, _page} = Factory.create_species_taxon_with_page()
      country = insert_country("Canada")
      subdivision = insert_subdivision("Manitoba", country)
      site = insert_site(country, subdivision)

      # Only World enabled; Canada/Manitoba not in settings
      user =
        user_fixture()
        |> put_log_settings([%{location_id: nil, life: true, year: true}])

      today = Date.utc_today()
      c = card(user, today, site)
      obs(c, Ornitho.Schema.Taxon.key(taxon))

      entries = Log.recent_entries(scope(user))
      {_date, day_entries} = hd(entries)

      lifer_entry = Enum.find(day_entries, &(&1.type == :life && is_nil(&1.area)))
      assert lifer_entry.covered_areas == []
    end

    test "covered_areas excludes areas where life is disabled even if year is enabled" do
      {taxon, _page} = Factory.create_species_taxon_with_page()
      country = insert_country("Canada")
      site = insert_site(country)

      # Canada year enabled, life disabled
      settings = [
        %{location_id: nil, life: true, year: true},
        %{location_id: country.id, life: false, year: true}
      ]

      user = user_fixture() |> put_log_settings(settings)

      today = Date.utc_today()
      c = card(user, today, site)
      obs(c, Ornitho.Schema.Taxon.key(taxon))

      entries = Log.recent_entries(scope(user))
      {_date, day_entries} = hd(entries)

      lifer_entry = Enum.find(day_entries, &(&1.type == :life && is_nil(&1.area)))
      refute Enum.any?(lifer_entry.covered_areas, fn {a, _} -> a.id == country.id end)
    end

    test "species with matching covered areas are grouped into one entry" do
      {t1, _} = Factory.create_species_taxon_with_page()
      {t2, _} = Factory.create_species_taxon_with_page()
      country = insert_country("Canada")
      site = insert_site(country)

      user =
        user_fixture()
        |> put_log_settings(all_enabled_settings([country]))

      today = Date.utc_today()
      c = card(user, today, site)
      obs(c, Ornitho.Schema.Taxon.key(t1))
      obs(c, Ornitho.Schema.Taxon.key(t2))

      entries = Log.recent_entries(scope(user))
      {_date, day_entries} = hd(entries)

      lifer_entries = Enum.filter(day_entries, &(&1.type == :life && is_nil(&1.area)))
      assert length(lifer_entries) == 1

      lifer_entry = hd(lifer_entries)
      assert length(lifer_entry.life_observations) == 2

      # covered_areas' list_total is the max (latest) across the group
      {_area, ca_total} =
        Enum.find(lifer_entry.covered_areas, fn {a, _} -> a.id == country.id end)

      assert ca_total == 2
    end

    test "world lifer and Canada-only lifer create two separate entries" do
      {t1, _} = Factory.create_species_taxon_with_page()
      {t2, _} = Factory.create_species_taxon_with_page()
      country_ca = insert_country("Canada", 1)
      country_ua = insert_country("Ukraine", 2)
      site_ca = insert_site(country_ca)
      site_ua = insert_site(country_ua)

      user =
        user_fixture()
        |> put_log_settings(all_enabled_settings([country_ca, country_ua]))

      # t2 was seen long ago in Ukraine (already a world lifer)
      long_ago = Date.add(Date.utc_today(), -30)
      c_old = card(user, long_ago, site_ua)
      obs(c_old, Ornitho.Schema.Taxon.key(t2))

      # Today: both in Canada
      today = Date.utc_today()
      c = card(user, today, site_ca)
      obs(c, Ornitho.Schema.Taxon.key(t1))
      obs(c, Ornitho.Schema.Taxon.key(t2))

      entries = Log.recent_entries(scope(user))
      today_entry = Enum.find(entries, fn {d, _} -> d == today end)
      {_date, day_entries} = today_entry

      # t1: world lifer (primary = World), covered areas include Canada
      world_lifer = Enum.find(day_entries, &(&1.type == :life && is_nil(&1.area)))
      assert world_lifer != nil
      assert length(world_lifer.life_observations) == 1
      assert Enum.any?(world_lifer.covered_areas, fn {a, _} -> a.id == country_ca.id end)

      # t2: Canada lifer as its own primary entry
      canada_lifer =
        Enum.find(day_entries, &(&1.type == :life && &1.area && &1.area.id == country_ca.id))

      assert canada_lifer != nil
      assert length(canada_lifer.life_observations) == 1
      assert canada_lifer.covered_areas == []
    end

    test "covered :life areas do not leak onto :year primaries" do
      {taxon, _page} = Factory.create_species_taxon_with_page()
      country_ca = insert_country("Canada", 1)
      country_ua = insert_country("Ukraine", 2)
      subdivision = insert_subdivision("Manitoba", country_ca)
      site_ca = insert_site(country_ca, subdivision)
      site_ua = insert_site(country_ua)

      user =
        user_fixture()
        |> put_log_settings(all_enabled_settings([country_ca, country_ua, subdivision]))

      # Seen in Ukraine last year — already world lifer and on the 2024 year list
      last_year = ~D[2024-06-15]
      c_old = card(user, last_year, site_ua)
      obs(c_old, Ornitho.Schema.Taxon.key(taxon))

      # Today: seen in Canada. This is a Canada lifer, Manitoba lifer, AND a
      # new 2026 year bird (at world and all ancestor scopes).
      today = Date.utc_today()
      c = card(user, today, site_ca)
      obs(c, Ornitho.Schema.Taxon.key(taxon))

      entries = Log.recent_entries(scope(user))
      today_entry = Enum.find(entries, fn {d, _} -> d == today end)
      {_date, day_entries} = today_entry

      # :life primary is Canada; Manitoba should be in its covered_areas.
      canada_life =
        Enum.find(day_entries, &(&1.type == :life && &1.area && &1.area.id == country_ca.id))

      assert canada_life != nil
      assert Enum.any?(canada_life.covered_areas, fn {a, _} -> a.id == subdivision.id end)

      # :year primary is world for the current year. It must NOT have any
      # covered :life areas attached.
      world_year =
        Enum.find(day_entries, &(&1.type == :year && is_nil(&1.area) && &1.year == today.year))

      assert world_year != nil
      assert world_year.covered_areas == []
    end

    test "year filter scopes to the given year, bypassing cutoff and limit" do
      user = user_fixture()
      country = insert_country("Canada")
      site = insert_site(country)

      {taxon_2020, _} = Factory.create_species_taxon_with_page()
      {taxon_2025, _} = Factory.create_species_taxon_with_page()

      # Observation far in the past (beyond any default cutoff)
      c1 = card(user, ~D[2020-06-15], site)
      obs(c1, Ornitho.Schema.Taxon.key(taxon_2020))

      # Observation in 2025
      c2 = card(user, ~D[2025-03-15], site)
      obs(c2, Ornitho.Schema.Taxon.key(taxon_2025))

      # cutoff_days would exclude 2020 data, but year filter finds it
      assert Log.recent_entries(scope(user), cutoff_days: 5) == []

      entries_2020 = Log.recent_entries(scope(user), year: 2020)
      assert [{~D[2020-06-15], _}] = entries_2020

      # Only 2025 entries returned, 2020 excluded
      entries_2025 = Log.recent_entries(scope(user), year: 2025)
      dates = Enum.map(entries_2025, fn {date, _} -> date end)
      assert ~D[2025-03-15] in dates
      refute Enum.any?(dates, &(&1.year == 2020))

      # Year with no observations returns empty
      assert Log.recent_entries(scope(user), year: 2023) == []
    end

    test "year filter returns all entries without limit, in ascending date order" do
      user = user_fixture()
      country = insert_country("Canada")
      site = insert_site(country)

      # Create observations on many different dates in 2025
      for i <- 1..5 do
        {taxon, _} = Factory.create_species_taxon_with_page()
        c = card(user, Date.new!(2025, i, 10), site)
        obs(c, Ornitho.Schema.Taxon.key(taxon))
      end

      # With year filter, all 5 dates should appear (no limit applied),
      # ordered chronologically ascending.
      entries = Log.recent_entries(scope(user), year: 2025)
      dates = Enum.map(entries, fn {date, _} -> date end)

      assert length(entries) == 5
      assert dates == Enum.sort(dates, {:asc, Date})
    end

    test "default (no year) returns dates in descending order" do
      user = user_fixture()
      country = insert_country("Canada")
      site = insert_site(country)

      today = Date.utc_today()

      for i <- 0..4 do
        {taxon, _} = Factory.create_species_taxon_with_page()
        c = card(user, Date.add(today, -i), site)
        obs(c, Ornitho.Schema.Taxon.key(taxon))
      end

      entries = Log.recent_entries(scope(user))
      dates = Enum.map(entries, fn {date, _} -> date end)

      assert dates == Enum.sort(dates, {:desc, Date})
    end

    test "log_settings with all disabled returns empty" do
      {taxon, _page} = Factory.create_species_taxon_with_page()
      country = insert_country("Canada")
      site = insert_site(country)

      settings = [
        %{location_id: nil, life: false, year: false},
        %{location_id: country.id, life: false, year: false}
      ]

      user = user_fixture() |> put_log_settings(settings)

      today = Date.utc_today()
      c = card(user, today, site)
      obs(c, Ornitho.Schema.Taxon.key(taxon))

      entries = Log.recent_entries(scope(user))
      assert entries == []
    end
  end

  describe "any_enabled?/1" do
    test "returns false for empty log_settings" do
      user = user_fixture()
      assert Log.any_enabled?(scope(user)) == false
    end

    test "returns true when at least one setting has life or year enabled" do
      settings = [%{location_id: nil, life: false, year: true}]
      user = user_fixture() |> put_log_settings(settings)

      assert Log.any_enabled?(scope(user)) == true
    end

    test "returns false when all settings have life and year disabled" do
      settings = [
        %{location_id: nil, life: false, year: false},
        %{location_id: 1, life: false, year: false}
      ]

      user = user_fixture() |> put_log_settings(settings)

      assert Log.any_enabled?(scope(user)) == false
    end
  end
end
