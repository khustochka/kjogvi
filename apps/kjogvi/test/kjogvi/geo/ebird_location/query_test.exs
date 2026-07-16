defmodule Kjogvi.Geo.EbirdLocation.QueryTest do
  use Kjogvi.DataCase, async: true

  alias Kjogvi.Geo
  alias Kjogvi.Geo.EbirdLocation

  describe "derive_status/1" do
    # The status is the shape of the eBird-vs-ISO subdivision sets only; link
    # progress is a separate axis (the "not fully linked" work queue) and does
    # not enter the shape, so these fixtures leave the link fields out.
    # `sub1_total` is the one count the shape reads: at 0 eBird has no
    # subdivisions to link and the country is complete whatever ISO holds.
    defp stats(overrides) do
      Map.merge(
        %{
          has_iso_country: true,
          code_set_equal: false,
          code_subset: false,
          name_set_match: false,
          sub1_total: 1,
          iso_sub1_total: 1
        },
        Map.new(overrides)
      )
    end

    test "matched when the code sets are identical" do
      assert EbirdLocation.Query.derive_status(stats(code_set_equal: true, code_subset: true)) ==
               :matched
    end

    test "matched with no subdivisions on either side (empty perfect match)" do
      assert EbirdLocation.Query.derive_status(stats(code_set_equal: true, code_subset: true)) ==
               :matched
    end

    test "ebird_only when the eBird country has no ISO counterpart" do
      assert EbirdLocation.Query.derive_status(stats(has_iso_country: false)) == :ebird_only
    end

    test "iso_extra when eBird sub1 codes are a strict subset of the ISO codes" do
      assert EbirdLocation.Query.derive_status(stats(code_subset: true)) == :iso_extra
    end

    test "matched when eBird has no subdivisions at all, whatever ISO holds (Monaco)" do
      # The empty eBird set is a subset of ISO's, but there is nothing to link:
      # the country row alone completes it, so this is not :iso_extra.
      assert EbirdLocation.Query.derive_status(stats(sub1_total: 0, code_subset: true)) ==
               :matched
    end

    test "ebird_only_subregions when ISO has no subdivisions but eBird does (Puerto Rico)" do
      assert EbirdLocation.Query.derive_status(stats(iso_sub1_total: 0)) ==
               :ebird_only_subregions
    end

    test "matched wins over ebird_only_subregions when neither side subdivides" do
      # Both empty: an (empty) perfect match, not a one-sided shape.
      assert EbirdLocation.Query.derive_status(
               stats(sub1_total: 0, iso_sub1_total: 0, code_set_equal: true)
             ) == :matched
    end

    test "name_candidate when the name sets match but codes differ" do
      assert EbirdLocation.Query.derive_status(stats(name_set_match: true)) == :name_candidate
    end

    test "mixed when subdivisions overlap only partially, by neither code nor name" do
      assert EbirdLocation.Query.derive_status(stats([])) == :mixed
    end
  end

  describe "country_statuses/0" do
    test "matched: every eBird row linked by code" do
      country = insert(:country, iso_code: "AD")
      sub1 = insert(:subdivision1, iso_code: "AD-02", country: country)

      insert(:ebird_location, code: "AD", location: country)
      insert(:ebird_subdivision1, country_code: "AD", code: "AD-02", location: sub1)

      assert %{
               status: :matched,
               country_linked: true,
               sub1_total: 1,
               sub1_linked: 1,
               iso_extra: 0
             } = Geo.Ebird.country_statuses()["AD"]
    end

    test "shape ignores link state: linked by a non-code pairing is still :mixed" do
      # eBird FR-V is linked to ISO FR-ARA — the sets agree by neither code nor
      # name, so the shape stays :mixed even though every row is linked.
      country = insert(:country, iso_code: "FR")
      sub1 = insert(:subdivision1, iso_code: "FR-ARA", country: country)

      insert(:ebird_location, code: "FR", location: country)
      insert(:ebird_subdivision1, country_code: "FR", code: "FR-V", location: sub1)

      assert %{status: :mixed} = Geo.Ebird.country_statuses()["FR"]
    end

    test "iso_extra keeps its shape once every eBird row is linked" do
      country = insert(:country, iso_code: "HU")
      sub1 = insert(:subdivision1, iso_code: "HU-BU", country: country)
      insert(:subdivision1, iso_code: "HU-BA", country: country)

      insert(:ebird_location, code: "HU", location: country)
      insert(:ebird_subdivision1, country_code: "HU", code: "HU-BU", location: sub1)

      assert %{status: :iso_extra, iso_extra: 1} =
               Geo.Ebird.country_statuses()["HU"]
    end

    test "matched: eBird models the country as one unit though ISO subdivides it (Monaco)" do
      country = insert(:country, iso_code: "MC")
      insert(:subdivision1, iso_code: "MC-FO", country: country)
      insert(:subdivision1, iso_code: "MC-CO", country: country)

      insert(:ebird_location, code: "MC", location: country)

      # Fully linked: the ISO subdivisions are context, not leftover work.
      assert %{status: :matched, sub1_total: 0, iso_extra: 2} =
               Geo.Ebird.country_statuses()["MC"]
    end

    test "ebird_only_subregions: ISO treats the country as one unit, eBird subdivides it (PR)" do
      country = insert(:country, iso_code: "PR")

      insert(:ebird_location, code: "PR", location: country)
      insert(:ebird_subdivision1, country_code: "PR", code: "PR-001", name: "Adjuntas")
      insert(:ebird_subdivision1, country_code: "PR", code: "PR-003", name: "Aguada")

      # No ISO side to match against: every row needs create-from-eBird, so this
      # is not :mixed (which means both sides subdivide and merely disagree).
      assert %{status: :ebird_only_subregions, sub1_total: 2, iso_extra: 0} =
               Geo.Ebird.country_statuses()["PR"]
    end

    test "matched: identical code sets, still unlinked (the bulk pass will link them)" do
      country = insert(:country, iso_code: "SI")
      insert(:subdivision1, iso_code: "SI-01", country: country)
      insert(:subdivision1, iso_code: "SI-02", country: country)

      insert(:ebird_location, code: "SI")
      insert(:ebird_subdivision1, country_code: "SI", code: "SI-01")
      insert(:ebird_subdivision1, country_code: "SI", code: "SI-02")

      assert %{status: :matched, code_set_equal: true, sub1_linked: 0} =
               Geo.Ebird.country_statuses()["SI"]
    end

    test "iso_extra: eBird sub1 codes are a strict subset of the ISO codes" do
      country = insert(:country, iso_code: "PT")
      insert(:subdivision1, iso_code: "PT-01", country: country)
      insert(:subdivision1, iso_code: "PT-02", country: country)
      insert(:subdivision1, iso_code: "PT-03", country: country)

      insert(:ebird_location, code: "PT")
      insert(:ebird_subdivision1, country_code: "PT", code: "PT-01")
      insert(:ebird_subdivision1, country_code: "PT", code: "PT-02")

      # Nothing is linked yet, but only PT-03 is a genuine extra: the codes eBird
      # shares are not extras just because the passes haven't run (the Botswana
      # case — 9 shared + 7 ISO-only reads 7, not 16).
      assert %{
               status: :iso_extra,
               has_iso_country: true,
               code_set_equal: false,
               code_subset: true,
               sub1_linked: 0,
               iso_extra: 1
             } =
               Geo.Ebird.country_statuses()["PT"]
    end

    test "name_candidate: names match (after normalization) but codes differ (Poland)" do
      # ISO keeps diacritics and non-decomposing letters; eBird flattens them.
      # Normalization folds both to the same form, so the name sets match while
      # the codes (ISO numeric vs eBird alphabetic) do not.
      country = insert(:country, iso_code: "PL")
      insert(:subdivision1, iso_code: "PL-02", name_en: "Dolnośląskie", country: country)
      insert(:subdivision1, iso_code: "PL-10", name_en: "Łódzkie", country: country)

      insert(:ebird_location, code: "PL")
      insert(:ebird_subdivision1, country_code: "PL", code: "PL-DS", name: "Dolnoslaskie")
      insert(:ebird_subdivision1, country_code: "PL", code: "PL-LD", name: "Lodzkie")

      assert %{status: :name_candidate, code_subset: false, name_set_match: true} =
               Geo.Ebird.country_statuses()["PL"]
    end

    test "ebird_only: eBird country with no ISO counterpart" do
      insert(:ebird_location, code: "XX")
      insert(:ebird_subdivision1, country_code: "XX", code: "XX-01")

      assert %{status: :ebird_only, has_iso_country: false, sub1_linked: 0} =
               Geo.Ebird.country_statuses()["XX"]
    end

    test "mixed shape is independent of link progress (some rows linked)" do
      # eBird has an extra subdivision ISO lacks (AF-XXX): the code sets overlap
      # only partially, so the shape is `:mixed` — and stays `:mixed` even though
      # one row is already linked, since the shape ignores link progress.
      country = insert(:country, iso_code: "AF")
      sub1 = insert(:subdivision1, iso_code: "AF-BAM", country: country)

      insert(:ebird_location, code: "AF", location: country)
      insert(:ebird_subdivision1, country_code: "AF", code: "AF-BAM", location: sub1)
      insert(:ebird_subdivision1, country_code: "AF", code: "AF-XXX", name: "No Match")

      assert %{status: :mixed, sub1_total: 2, sub1_linked: 1} =
               Geo.Ebird.country_statuses()["AF"]
    end

    test "mixed: subdivisions overlap only partially, by neither code nor name" do
      country = insert(:country, iso_code: "GS")

      insert(:subdivision1, iso_code: "GS-XX", name_en: "Real Place", country: country)

      insert(:ebird_location, code: "GS")
      insert(:ebird_subdivision1, country_code: "GS", code: "GS-99", name: "High Seas Junk")

      assert %{status: :mixed} = Geo.Ebird.country_statuses()["GS"]
    end

    test "ebird_only keeps its shape even after the country is manually linked" do
      # No ISO country carries code XK, so the shape is :ebird_only regardless of
      # the manual link — shape is a property of the sets, not of link state.
      country = insert(:country, iso_code: nil, name_en: "Kosovo")
      sub1 = insert(:subdivision1, country: country)

      insert(:ebird_location, code: "XK", location: country)
      insert(:ebird_subdivision1, country_code: "XK", code: "XK-01", location: sub1)

      assert %{status: :ebird_only, iso_extra: 0} =
               Geo.Ebird.country_statuses()["XK"]
    end

    test "country without any subdivision rows on either side is matched" do
      country = insert(:country, iso_code: "GI")
      insert(:ebird_location, code: "GI", location: country)

      assert %{status: :matched, sub1_total: 0, iso_extra: 0} =
               Geo.Ebird.country_statuses()["GI"]
    end

    test "matched: unlinked country with no subdivisions on either side" do
      insert(:country, iso_code: "MD")
      insert(:ebird_location, code: "MD")

      assert %{status: :matched, has_iso_country: true, code_set_equal: true, sub1_total: 0} =
               Geo.Ebird.country_statuses()["MD"]
    end

    test "covers every eBird country" do
      insert(:ebird_location, code: "AA")
      insert(:ebird_location, code: "BB")

      assert Geo.Ebird.country_statuses() |> Map.keys() |> Enum.sort() == ["AA", "BB"]
    end
  end

  describe "country_status/1" do
    test "returns the single country's entry" do
      country = insert(:country, iso_code: "AD")
      insert(:ebird_location, code: "AD", location: country)
      insert(:ebird_location, code: "XX")

      assert %{status: :matched} = Geo.Ebird.country_status("AD")
      assert %{status: :ebird_only} = Geo.Ebird.country_status("XX")
    end

    test "returns nil for an unknown code" do
      assert Geo.Ebird.country_status("ZZ") == nil
    end
  end
end
