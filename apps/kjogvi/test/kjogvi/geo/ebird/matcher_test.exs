defmodule Kjogvi.Geo.Ebird.MatcherTest do
  use Kjogvi.DataCase, async: false

  @moduletag :capture_log

  alias Kjogvi.Geo.Ebird.Matcher
  alias Kjogvi.Geo.EbirdLocation
  alias Kjogvi.Repo

  defp reload(ebird_row), do: Repo.get!(EbirdLocation, ebird_row.id)

  describe "normalize_name/1" do
    test "strips diacritics, downcases, collapses punctuation and whitespace" do
      assert Matcher.normalize_name("Rhône–Alpes") == "rhone alpes"
      assert Matcher.normalize_name("Saint-Denis") == "saint denis"
      assert Matcher.normalize_name("Co. Kerry") == "co kerry"
      assert Matcher.normalize_name("  Århus   County ") == "arhus county"
      assert Matcher.normalize_name("Baden-Württemberg") == "baden wurttemberg"
    end

    test "folds non-decomposing Latin letters to their base form" do
      # These do not decompose under NFD, so the diacritic strip alone leaves
      # them; eBird flattens them while ISO keeps them.
      assert Matcher.normalize_name("Łódzkie") == "lodzkie"
      assert Matcher.normalize_name("Malopolskie") == Matcher.normalize_name("Małopolskie")
      assert Matcher.normalize_name("Sør-Trøndelag") == "sor trondelag"
      assert Matcher.normalize_name("Þingeyjarsýsla") == "thingeyjarsysla"
    end

    test "nil and empty names normalize to the empty string" do
      assert Matcher.normalize_name(nil) == ""
      assert Matcher.normalize_name("") == ""
      assert Matcher.normalize_name(" - ") == ""
    end
  end

  describe "match_country/2 code passes" do
    test "links the country row and subdivision1 rows by iso code" do
      country = insert(:country, iso_code: "AD")
      sub1_a = insert(:subdivision1, iso_code: "AD-02", country: country)
      sub1_b = insert(:subdivision1, iso_code: "AD-03", country: country)

      ebird_country = insert(:ebird_location, code: "AD")
      ebird_a = insert(:ebird_subdivision1, country_code: "AD", code: "AD-02")
      ebird_b = insert(:ebird_subdivision1, country_code: "AD", code: "AD-03")

      assert Matcher.match_country("AD") == %{code: 3, name: 0, left: 0}

      assert reload(ebird_country).location_id == country.id
      assert reload(ebird_a).location_id == sub1_a.id
      assert reload(ebird_b).location_id == sub1_b.id
    end

    test "never links to a subdivision of another country" do
      insert(:country, iso_code: "AD")
      other_country = insert(:country, iso_code: "XY")
      insert(:subdivision1, iso_code: "AD-02", name_en: "Canillo", country: other_country)

      insert(:ebird_location, code: "AD")
      ebird_sub1 = insert(:ebird_subdivision1, country_code: "AD", code: "AD-02", name: "Canillo")

      assert Matcher.match_country("AD") == %{code: 1, name: 0, left: 1}
      assert reload(ebird_sub1).location_id == nil
    end

    test "eBird-only country gets no subdivision passes" do
      insert(:ebird_location, code: "XK")
      insert(:ebird_subdivision1, country_code: "XK", code: "XK-01")
      insert(:ebird_subdivision1, country_code: "XK", code: "XK-02")

      assert Matcher.match_country("XK") == %{code: 0, name: 0, left: 3}
    end

    test "a manually linked country row anchors the code pass" do
      # eBird-only country linked by hand to a created common country.
      country = insert(:country, iso_code: nil, name_en: "Kosovo")
      insert(:ebird_location, code: "XK", location: country)
      sub1 = insert(:subdivision1, iso_code: "XK-01", country: country)
      ebird_sub1 = insert(:ebird_subdivision1, country_code: "XK", code: "XK-01")

      assert Matcher.match_country("XK") == %{code: 1, name: 0, left: 0}
      assert reload(ebird_sub1).location_id == sub1.id
    end
  end

  describe "match_country/2 name pass" do
    test "links leftovers by normalized name" do
      country = insert(:country, iso_code: "FR")
      sub1 = insert(:subdivision1, iso_code: "FR-ARA", name_en: "Rhône–Alpes", country: country)

      insert(:ebird_location, code: "FR")

      ebird_sub1 =
        insert(:ebird_subdivision1, country_code: "FR", code: "FR-V", name: "Rhone-Alpes")

      assert Matcher.match_country("FR") == %{code: 1, name: 1, left: 0}
      assert reload(ebird_sub1).location_id == sub1.id
    end

    test "skips names ambiguous on the eBird side" do
      country = insert(:country, iso_code: "FR")
      insert(:subdivision1, iso_code: "FR-A", name_en: "Centre", country: country)

      insert(:ebird_location, code: "FR")
      ebird_a = insert(:ebird_subdivision1, country_code: "FR", code: "FR-X", name: "Centre")
      ebird_b = insert(:ebird_subdivision1, country_code: "FR", code: "FR-Y", name: "Centre")

      assert Matcher.match_country("FR") == %{code: 1, name: 0, left: 2}
      assert reload(ebird_a).location_id == nil
      assert reload(ebird_b).location_id == nil
    end

    test "skips names ambiguous on the common side" do
      country = insert(:country, iso_code: "FR")
      insert(:subdivision1, iso_code: "FR-A", name_en: "Centre", country: country)
      insert(:subdivision1, iso_code: "FR-B", name_en: "Centre", country: country)

      insert(:ebird_location, code: "FR")
      ebird_sub1 = insert(:ebird_subdivision1, country_code: "FR", code: "FR-X", name: "Centre")

      assert Matcher.match_country("FR") == %{code: 1, name: 0, left: 1}
      assert reload(ebird_sub1).location_id == nil
    end

    test "candidates come only from the matched country" do
      insert(:country, iso_code: "FR")
      other_country = insert(:country, iso_code: "XY")
      insert(:subdivision1, iso_code: "XY-01", name_en: "Centre", country: other_country)

      insert(:ebird_location, code: "FR")
      ebird_sub1 = insert(:ebird_subdivision1, country_code: "FR", code: "FR-X", name: "Centre")

      assert Matcher.match_country("FR") == %{code: 1, name: 0, left: 1}
      assert reload(ebird_sub1).location_id == nil
    end
  end

  describe "match_country/2 safety" do
    test "never overwrites an existing link" do
      country = insert(:country, iso_code: "AD")
      insert(:subdivision1, iso_code: "AD-02", country: country)
      elsewhere = insert(:subdivision1, country: country)

      insert(:ebird_location, code: "AD")

      ebird_sub1 =
        insert(:ebird_subdivision1, country_code: "AD", code: "AD-02", location: elsewhere)

      assert Matcher.match_country("AD") == %{code: 1, name: 0, left: 0}
      assert reload(ebird_sub1).location_id == elsewhere.id
    end

    test "never steals a common location linked from another eBird row" do
      country = insert(:country, iso_code: "AD")
      sub1 = insert(:subdivision1, iso_code: "AD-02", name_en: "Canillo", country: country)
      insert(:ebird_subdivision1, country_code: "AD", code: "AD-98", location: sub1)

      insert(:ebird_location, code: "AD")
      ebird_sub1 = insert(:ebird_subdivision1, country_code: "AD", code: "AD-02", name: "Canillo")

      assert Matcher.match_country("AD") == %{code: 1, name: 0, left: 1}
      assert reload(ebird_sub1).location_id == nil
    end

    test "re-running changes nothing" do
      country = insert(:country, iso_code: "AD")
      insert(:subdivision1, iso_code: "AD-02", country: country)
      insert(:subdivision1, iso_code: "FR-ARA", name_en: "Rhône–Alpes", country: country)

      insert(:ebird_location, code: "AD")
      insert(:ebird_subdivision1, country_code: "AD", code: "AD-02")
      insert(:ebird_subdivision1, country_code: "AD", code: "AD-X", name: "Rhone-Alpes")
      insert(:ebird_subdivision1, country_code: "AD", code: "AD-Y", name: "No Match")

      assert Matcher.match_country("AD") == %{code: 2, name: 1, left: 1}

      links = EbirdLocation |> Repo.all() |> Map.new(&{&1.code, &1.location_id})
      assert Matcher.match_country("AD") == %{code: 0, name: 0, left: 1}
      assert EbirdLocation |> Repo.all() |> Map.new(&{&1.code, &1.location_id}) == links
    end

    test "subdivision2 rows are untouched and not counted" do
      country = insert(:country, iso_code: "AD")
      insert(:subdivision1, iso_code: "AD-02", country: country)

      insert(:ebird_location, code: "AD")
      insert(:ebird_subdivision1, country_code: "AD", code: "AD-02")

      ebird_sub2 =
        insert(:ebird_subdivision1,
          country_code: "AD",
          code: "AD-02-C",
          location_type: :subdivision2,
          subnational1_code: "AD-02",
          subnational2_code: "AD-02-C"
        )

      assert Matcher.match_country("AD") == %{code: 2, name: 0, left: 0}
      assert reload(ebird_sub2).location_id == nil
    end
  end

  describe "match_all/0" do
    test "links country rows and the subdivisions of perfect-match countries" do
      # AD: eBird and ISO sub1 code sets identical → :matched, subdivisions linked.
      ad = insert(:country, iso_code: "AD")
      ad_02 = insert(:subdivision1, iso_code: "AD-02", country: ad)
      ad_03 = insert(:subdivision1, iso_code: "AD-03", country: ad)

      ebird_ad = insert(:ebird_location, code: "AD")
      ebird_ad_02 = insert(:ebird_subdivision1, country_code: "AD", code: "AD-02")
      ebird_ad_03 = insert(:ebird_subdivision1, country_code: "AD", code: "AD-03")

      assert Matcher.match_all() == %{countries: 1, subdivisions: 2, matched: 1}

      assert reload(ebird_ad).location_id == ad.id
      assert reload(ebird_ad_02).location_id == ad_02.id
      assert reload(ebird_ad_03).location_id == ad_03.id
    end

    test "links a country with no subdivisions on either side (still :matched)" do
      country = insert(:country, iso_code: "SG")
      ebird_country = insert(:ebird_location, code: "SG")

      assert Matcher.match_all() == %{countries: 1, subdivisions: 0, matched: 1}
      assert reload(ebird_country).location_id == country.id
    end

    test "links the country but leaves subdivisions of a code-mismatched country untouched" do
      # ISO has an extra subdivision eBird doesn't cover → :iso_extra, subs left.
      country = insert(:country, iso_code: "HU")
      insert(:subdivision1, iso_code: "HU-BU", country: country)
      insert(:subdivision1, iso_code: "HU-BK", country: country)

      ebird_country = insert(:ebird_location, code: "HU")
      ebird_sub1 = insert(:ebird_subdivision1, country_code: "HU", code: "HU-BU")

      assert Matcher.match_all() == %{countries: 1, subdivisions: 0, matched: 0}
      assert reload(ebird_country).location_id == country.id
      assert reload(ebird_sub1).location_id == nil
    end

    test "matches every clean country in one pass and mixes cleanly with dirty ones" do
      clean = insert(:country, iso_code: "AD")
      clean_sub1 = insert(:subdivision1, iso_code: "AD-02", country: clean)
      dirty = insert(:country, iso_code: "HU")
      insert(:subdivision1, iso_code: "HU-BU", country: dirty)
      insert(:subdivision1, iso_code: "HU-BK", country: dirty)

      insert(:ebird_location, code: "AD")
      ebird_clean_sub1 = insert(:ebird_subdivision1, country_code: "AD", code: "AD-02")
      insert(:ebird_location, code: "HU")
      ebird_dirty_sub1 = insert(:ebird_subdivision1, country_code: "HU", code: "HU-BU")

      assert Matcher.match_all() == %{countries: 2, subdivisions: 1, matched: 1}
      assert reload(ebird_clean_sub1).location_id == clean_sub1.id
      assert reload(ebird_dirty_sub1).location_id == nil
    end

    test "leaves eBird-only countries and their subdivisions unlinked" do
      insert(:ebird_location, code: "XK")
      ebird_sub1 = insert(:ebird_subdivision1, country_code: "XK", code: "XK-01")

      assert Matcher.match_all() == %{countries: 0, subdivisions: 0, matched: 0}
      assert reload(ebird_sub1).location_id == nil
    end

    test "does not run the name pass (a name_candidate country's subs stay unlinked)" do
      country = insert(:country, iso_code: "PL")
      insert(:subdivision1, iso_code: "PL-DS", name_en: "Dolnośląskie", country: country)

      insert(:ebird_location, code: "PL")

      ebird_sub1 =
        insert(:ebird_subdivision1, country_code: "PL", code: "PL-02", name: "Dolnoslaskie")

      assert Matcher.match_all() == %{countries: 1, subdivisions: 0, matched: 0}
      assert reload(ebird_sub1).location_id == nil
    end

    test "never overwrites existing links and is idempotent" do
      country = insert(:country, iso_code: "AD")
      sub1 = insert(:subdivision1, iso_code: "AD-02", country: country)
      elsewhere = insert(:subdivision1, iso_code: "AD-03", country: country)

      insert(:ebird_location, code: "AD")
      ebird_a = insert(:ebird_subdivision1, country_code: "AD", code: "AD-02")

      pinned =
        insert(:ebird_subdivision1, country_code: "AD", code: "AD-03", location: elsewhere)

      # AD-04 exists on eBird but has no ISO counterpart, so the code sets differ:
      # not :matched, subdivisions are left alone.
      ebird_c = insert(:ebird_subdivision1, country_code: "AD", code: "AD-04")

      Matcher.match_all()
      links = EbirdLocation |> Repo.all() |> Map.new(&{&1.code, &1.location_id})

      assert Matcher.match_all() == %{countries: 0, subdivisions: 0, matched: 0}
      assert EbirdLocation |> Repo.all() |> Map.new(&{&1.code, &1.location_id}) == links

      assert reload(ebird_a).location_id == nil
      assert reload(pinned).location_id == elsewhere.id
      assert reload(ebird_c).location_id == nil
      assert Repo.reload!(sub1)
    end

    test "does not touch subdivision2 rows" do
      country = insert(:country, iso_code: "AD")
      insert(:subdivision1, iso_code: "AD-02", country: country)

      insert(:ebird_location, code: "AD")
      insert(:ebird_subdivision1, country_code: "AD", code: "AD-02")

      ebird_sub2 =
        insert(:ebird_subdivision1,
          country_code: "AD",
          code: "AD-02-C",
          location_type: :subdivision2,
          subnational1_code: "AD-02",
          subnational2_code: "AD-02-C"
        )

      assert Matcher.match_all() == %{countries: 1, subdivisions: 1, matched: 1}
      assert reload(ebird_sub2).location_id == nil
    end

    test "emits a match_all telemetry stop event with the summary" do
      ref = make_ref()
      test_pid = self()

      :telemetry.attach(
        {__MODULE__, ref},
        [:kjogvi, :geo, :ebird, :match_all, :stop],
        fn event, measurements, metadata, _ ->
          send(test_pid, {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach({__MODULE__, ref}) end)

      insert(:country, iso_code: "AD")
      insert(:ebird_location, code: "AD")

      assert Matcher.match_all() == %{countries: 1, subdivisions: 0, matched: 1}

      assert_received {:telemetry, [:kjogvi, :geo, :ebird, :match_all, :stop], %{duration: _},
                       %{result: :ok, countries: 1, subdivisions: 0, matched: 1}}
    end
  end

  test "emits a telemetry stop event with the summary" do
    ref = make_ref()
    test_pid = self()

    :telemetry.attach(
      {__MODULE__, ref},
      [:kjogvi, :geo, :ebird, :match, :stop],
      fn event, measurements, metadata, _ ->
        send(test_pid, {:telemetry, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach({__MODULE__, ref}) end)

    insert(:country, iso_code: "AD")
    insert(:ebird_location, code: "AD")

    assert Matcher.match_country("AD") == %{code: 1, name: 0, left: 0}

    assert_received {:telemetry, [:kjogvi, :geo, :ebird, :match, :stop], %{duration: _},
                     %{result: :ok, country_code: "AD", code: 1, name: 0, left: 0}}
  end
end
