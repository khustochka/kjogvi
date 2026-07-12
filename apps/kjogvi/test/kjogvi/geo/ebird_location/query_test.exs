defmodule Kjogvi.Geo.EbirdLocation.QueryTest do
  use Kjogvi.DataCase, async: true

  alias Kjogvi.Geo
  alias Kjogvi.Geo.EbirdLocation

  describe "derive_status/1" do
    defp stats(overrides) do
      Map.merge(
        %{
          country_linked: true,
          country_code_match: true,
          sub1_total: 2,
          sub1_linked: 2,
          sub1_code_matched: 2,
          iso_extra: 0
        },
        Map.new(overrides)
      )
    end

    test "matched when everything is linked code-consistently" do
      assert EbirdLocation.Query.derive_status(stats([])) == :matched
    end

    test "matched_mixed when some links are not by code" do
      assert EbirdLocation.Query.derive_status(stats(sub1_code_matched: 1)) == :matched_mixed
      assert EbirdLocation.Query.derive_status(stats(country_code_match: false)) == :matched_mixed
    end

    test "matched_iso_extra when ISO has extra subdivisions" do
      assert EbirdLocation.Query.derive_status(stats(iso_extra: 1)) == :matched_iso_extra
    end

    test "matched_iso_extra outranks matched_mixed" do
      assert EbirdLocation.Query.derive_status(stats(sub1_code_matched: 1, iso_extra: 1)) ==
               :matched_iso_extra
    end

    test "partial when some rows are unlinked" do
      assert EbirdLocation.Query.derive_status(stats(sub1_linked: 1, sub1_code_matched: 1)) ==
               :partial

      assert EbirdLocation.Query.derive_status(stats(country_linked: false)) == :partial
    end

    test "unmatched when nothing is linked" do
      assert EbirdLocation.Query.derive_status(
               stats(country_linked: false, sub1_linked: 0, sub1_code_matched: 0)
             ) == :unmatched
    end
  end

  describe "ebird_country_statuses/0" do
    test "matched: country and subdivisions linked by code, sets equal" do
      country = insert(:country, iso_code: "AD")
      sub1 = insert(:subdivision1, iso_code: "AD-02", country: country)

      insert(:ebird_location, code: "AD", location: country)
      insert(:ebird_subdivision1, country_code: "AD", code: "AD-02", location: sub1)

      assert %{
               status: :matched,
               country_linked: true,
               country_code_match: true,
               sub1_total: 1,
               sub1_linked: 1,
               sub1_code_matched: 1,
               iso_sub1_total: 1,
               iso_extra: 0
             } = Geo.ebird_country_statuses()["AD"]
    end

    test "matched_mixed: a link that is not code-consistent" do
      country = insert(:country, iso_code: "FR")
      sub1 = insert(:subdivision1, iso_code: "FR-ARA", country: country)

      insert(:ebird_location, code: "FR", location: country)
      insert(:ebird_subdivision1, country_code: "FR", code: "FR-V", location: sub1)

      assert %{status: :matched_mixed, sub1_code_matched: 0} = Geo.ebird_country_statuses()["FR"]
    end

    test "matched_iso_extra: an ISO subdivision with no eBird counterpart" do
      country = insert(:country, iso_code: "HU")
      sub1 = insert(:subdivision1, iso_code: "HU-BU", country: country)
      insert(:subdivision1, iso_code: "HU-BA", country: country)

      insert(:ebird_location, code: "HU", location: country)
      insert(:ebird_subdivision1, country_code: "HU", code: "HU-BU", location: sub1)

      assert %{status: :matched_iso_extra, iso_sub1_total: 2, iso_extra: 1} =
               Geo.ebird_country_statuses()["HU"]
    end

    test "partial: some subdivisions unlinked" do
      country = insert(:country, iso_code: "AF")
      sub1 = insert(:subdivision1, iso_code: "AF-BAM", country: country)

      insert(:ebird_location, code: "AF", location: country)
      insert(:ebird_subdivision1, country_code: "AF", code: "AF-BAM", location: sub1)
      insert(:ebird_subdivision1, country_code: "AF", code: "AF-XXX")

      assert %{status: :partial, sub1_total: 2, sub1_linked: 1} =
               Geo.ebird_country_statuses()["AF"]
    end

    test "unmatched: nothing linked" do
      insert(:ebird_location, code: "XX")
      insert(:ebird_subdivision1, country_code: "XX", code: "XX-01")

      assert %{status: :unmatched, sub1_total: 1, sub1_linked: 0, iso_sub1_total: 0} =
               Geo.ebird_country_statuses()["XX"]
    end

    test "eBird-only country manually linked anchors ISO stats via the link" do
      country = insert(:country, iso_code: nil, name_en: "Kosovo")
      insert(:subdivision1, country: country)

      insert(:ebird_location, code: "XK", location: country)

      assert %{
               status: :matched_iso_extra,
               country_code_match: false,
               iso_sub1_total: 1,
               iso_extra: 1
             } = Geo.ebird_country_statuses()["XK"]
    end

    test "country without any subdivision rows on either side is matched" do
      country = insert(:country, iso_code: "GI")
      insert(:ebird_location, code: "GI", location: country)

      assert %{status: :matched, sub1_total: 0, iso_sub1_total: 0} =
               Geo.ebird_country_statuses()["GI"]
    end

    test "covers every eBird country" do
      insert(:ebird_location, code: "AA")
      insert(:ebird_location, code: "BB")

      assert Geo.ebird_country_statuses() |> Map.keys() |> Enum.sort() == ["AA", "BB"]
    end
  end

  describe "ebird_country_status/1" do
    test "returns the single country's entry" do
      country = insert(:country, iso_code: "AD")
      insert(:ebird_location, code: "AD", location: country)
      insert(:ebird_location, code: "XX")

      assert %{status: :matched} = Geo.ebird_country_status("AD")
      assert %{status: :unmatched} = Geo.ebird_country_status("XX")
    end

    test "returns nil for an unknown code" do
      assert Geo.ebird_country_status("ZZ") == nil
    end
  end
end
