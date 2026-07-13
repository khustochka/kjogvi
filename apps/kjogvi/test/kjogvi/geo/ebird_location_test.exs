defmodule Kjogvi.Geo.EbirdLocationTest do
  use Kjogvi.DataCase, async: true

  alias Kjogvi.Geo.EbirdLocation

  describe "code_match?/1" do
    test "false for an unlinked row" do
      row = build(:ebird_location, code: "AD", location_id: nil)

      refute EbirdLocation.code_match?(row)
    end

    test "country row: linked location's iso_code equals the eBird code" do
      matched = build(:ebird_location, code: "AD", location_id: 1)
      matched = %{matched | location: build(:country, iso_code: "AD")}

      other = build(:ebird_location, code: "XK", location_id: 1)
      other = %{other | location: build(:country, iso_code: "RS")}

      assert EbirdLocation.code_match?(matched)
      refute EbirdLocation.code_match?(other)
    end

    test "subdivision1 row: linked location's iso_code equals subnational1_code" do
      matched = build(:ebird_subdivision1, country_code: "AD", code: "AD-02", location_id: 1)
      matched = %{matched | location: build(:subdivision1, iso_code: "AD-02")}

      other = build(:ebird_subdivision1, country_code: "AD", code: "AD-03", location_id: 1)
      other = %{other | location: build(:subdivision1, iso_code: "AD-99")}

      assert EbirdLocation.code_match?(matched)
      refute EbirdLocation.code_match?(other)
    end
  end
end
