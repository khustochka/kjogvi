defmodule Kjogvi.Birding.LogTest do
  use Kjogvi.DataCase, async: true

  import Kjogvi.UsersFixtures

  alias Kjogvi.Birding.Log
  alias Kjogvi.Birding.Lifelist
  alias Kjogvi.Factory
  alias Kjogvi.GeoFixtures

  # Build a scope for a given user, optionally with log_settings on extras
  defp scope(user, log_settings \\ nil) do
    user =
      if log_settings do
        put_in(user.extras.log_settings, log_settings)
      else
        user
      end

    %Lifelist.Scope{user: user, include_private: false}
  end

  # Build log_settings that enable life+year for World and a list of locations
  defp all_enabled(locations) do
    alias Kjogvi.Users.User.Extras.LogSetting

    world = %LogSetting{location_id: nil, life: true, year: true}

    location_settings =
      Enum.map(locations, fn loc ->
        %LogSetting{location_id: loc.id, life: true, year: true}
      end)

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

    test "a lifer suppresses country and subdivision total entries" do
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
    end

    test "country total is shown when species is not a world lifer" do
      user = user_fixture()
      {taxon, _page} = Factory.create_species_taxon_with_page()
      country_ca = insert_country("Canada", 1)
      country_ua = insert_country("Ukraine", 2)
      site_ca = insert_site(country_ca)
      site_ua = insert_site(country_ua)

      # Saw species in Ukraine first (so not a world lifer when seeing in Canada)
      yesterday = Date.add(Date.utc_today(), -1)
      today = Date.utc_today()

      c1 = card(user, yesterday, site_ua)
      obs(c1, Ornitho.Schema.Taxon.key(taxon))

      c2 = card(user, today, site_ca)
      obs(c2, Ornitho.Schema.Taxon.key(taxon))

      settings = all_enabled([country_ca, country_ua])
      entries = Log.recent_entries(scope(user, settings))
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

    test "subdivision total is suppressed when country total is present" do
      user = user_fixture()
      {taxon, _page} = Factory.create_species_taxon_with_page()
      country = insert_country("Canada")
      subdivision = insert_subdivision("Manitoba", country)
      site = insert_site(country, subdivision)

      # First time in Canada (also first in Manitoba)
      today = Date.utc_today()
      c = card(user, today, site)
      obs(c, Ornitho.Schema.Taxon.key(taxon))

      entries = Log.recent_entries(scope(user))
      {_date, day_entries} = hd(entries)

      # Subdivision total should be suppressed since Canada total covers it
      sub_total =
        Enum.find(day_entries, &(&1.type == :life && &1.area && &1.area.id == subdivision.id))

      assert sub_total == nil
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

    test "lifer suppresses year entry for the same area" do
      user = user_fixture()
      {taxon, _page} = Factory.create_species_taxon_with_page()
      country = insert_country("Canada")
      site = insert_site(country)

      today = Date.utc_today()
      c = card(user, today, site)
      obs(c, Ornitho.Schema.Taxon.key(taxon))

      entries = Log.recent_entries(scope(user))
      {_date, day_entries} = hd(entries)

      # World total present
      assert Enum.any?(day_entries, &(&1.type == :life && is_nil(&1.area)))

      # World year entry should be suppressed (lifer covers it)
      refute Enum.any?(day_entries, &(&1.type == :year && is_nil(&1.area)))
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
      user = user_fixture()
      {taxon, _page} = Factory.create_species_taxon_with_page()
      country_ca = insert_country("Canada", 1)
      country_ua = insert_country("Ukraine", 2)
      site_ca = insert_site(country_ca)
      site_ua = insert_site(country_ua)

      # Saw species in Ukraine first (world lifer yesterday)
      yesterday = Date.add(Date.utc_today(), -1)
      today = Date.utc_today()

      c1 = card(user, yesterday, site_ua)
      obs(c1, Ornitho.Schema.Taxon.key(taxon))

      # Saw in Canada today (new for Canada, not a world lifer)
      c2 = card(user, today, site_ca)
      obs(c2, Ornitho.Schema.Taxon.key(taxon))

      # Disable world life, keep country life
      settings = [
        %Kjogvi.Users.User.Extras.LogSetting{location_id: nil, life: false, year: true},
        %Kjogvi.Users.User.Extras.LogSetting{location_id: country_ca.id, life: true, year: true},
        %Kjogvi.Users.User.Extras.LogSetting{location_id: country_ua.id, life: true, year: true}
      ]

      entries = Log.recent_entries(scope(user, settings))

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
      user = user_fixture()
      {taxon, _page} = Factory.create_species_taxon_with_page()
      country_ca = insert_country("Canada", 1)
      country_ua = insert_country("Ukraine", 2)
      site_ca = insert_site(country_ca)
      site_ua = insert_site(country_ua)

      yesterday = Date.add(Date.utc_today(), -1)
      today = Date.utc_today()

      c1 = card(user, yesterday, site_ua)
      obs(c1, Ornitho.Schema.Taxon.key(taxon))

      c2 = card(user, today, site_ca)
      obs(c2, Ornitho.Schema.Taxon.key(taxon))

      # Disable Canada entries
      settings = [
        %Kjogvi.Users.User.Extras.LogSetting{
          location_id: country_ca.id,
          life: false,
          year: false
        }
      ]

      entries = Log.recent_entries(scope(user, settings))
      today_entry = Enum.find(entries, fn {date, _} -> date == today end)

      # Canada entry should not appear
      if today_entry do
        {_date, day_entries} = today_entry
        refute Enum.any?(day_entries, &(&1.area && &1.area.id == country_ca.id))
      end
    end

    test "log_settings with all disabled returns empty" do
      user = user_fixture()
      {taxon, _page} = Factory.create_species_taxon_with_page()
      country = insert_country("Canada")
      site = insert_site(country)

      today = Date.utc_today()
      c = card(user, today, site)
      obs(c, Ornitho.Schema.Taxon.key(taxon))

      settings = [
        %Kjogvi.Users.User.Extras.LogSetting{location_id: nil, life: false, year: false},
        %Kjogvi.Users.User.Extras.LogSetting{
          location_id: country.id,
          life: false,
          year: false
        }
      ]

      entries = Log.recent_entries(scope(user, settings))
      assert entries == []
    end
  end

  describe "any_enabled?/1" do
    test "returns false for empty log_settings" do
      user = user_fixture()
      assert Log.any_enabled?(scope(user)) == false
    end

    test "returns true when at least one setting has life or year enabled" do
      user = user_fixture()

      settings = [
        %Kjogvi.Users.User.Extras.LogSetting{location_id: nil, life: false, year: true}
      ]

      assert Log.any_enabled?(scope(user, settings)) == true
    end

    test "returns false when all settings have life and year disabled" do
      user = user_fixture()

      settings = [
        %Kjogvi.Users.User.Extras.LogSetting{location_id: nil, life: false, year: false},
        %Kjogvi.Users.User.Extras.LogSetting{location_id: 1, life: false, year: false}
      ]

      assert Log.any_enabled?(scope(user, settings)) == false
    end
  end
end
