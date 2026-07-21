defmodule Kjogvi.Ebird.CsvImport.ConverterTest do
  use ExUnit.Case, async: true

  alias Kjogvi.Ebird.CsvImport.Converter

  # A row as `CSV.decode!(headers: true)` yields it — string keys from the
  # export's header line.
  defp row(overrides) do
    Map.merge(
      %{
        "Submission ID" => "S25954162",
        "Common Name" => "Black-bellied Whistling-Duck",
        "Scientific Name" => "Dendrocygna autumnalis",
        "Count" => "5",
        "State/Province" => "US-TX",
        "County" => "Bexar",
        "Location ID" => "L956160",
        "Location" => "Brackenridge Park--Joske Pavilion & Lambert Beach",
        "Latitude" => "29.4629383",
        "Longitude" => "-98.4698155",
        "Date" => "2015-11-14",
        "Time" => "01:00 PM",
        "Protocol" => "eBird - Traveling Count",
        "Duration (Min)" => "160",
        "All Obs Reported" => "1",
        "Distance Traveled (km)" => "5.5",
        "Area Covered (ha)" => "",
        "Number of Observers" => "1",
        "Breeding Code" => "",
        "Observation Details" => "",
        "Checklist Comments" => "",
        "ML Catalog Numbers" => "130552881"
      },
      overrides
    )
  end

  describe "user_location_attrs/1" do
    test "extracts eBird's location id, name, state code and county" do
      assert Converter.user_location_attrs(row(%{})) == %{
               ebird_loc_id: "L956160",
               name: "Brackenridge Park--Joske Pavilion & Lambert Beach",
               state: "US-TX",
               county: "Bexar",
               lat: "29.4629383",
               lon: "-98.4698155"
             }
    end

    test "blanks become nil" do
      attrs = Converter.user_location_attrs(row(%{"County" => "", "State/Province" => ""}))
      assert attrs.county == nil
      assert attrs.state == nil
    end
  end

  describe "checklist_attrs/1" do
    test "maps the checklist-wide fields" do
      assert {:ok, attrs} = Converter.checklist_attrs(row(%{}))

      assert attrs.ebird_id == "S25954162"
      assert attrs.observ_date == ~D[2015-11-14]
      assert attrs.start_time == ~T[13:00:00]
      assert attrs.effort_type == "TRAVEL"
      assert attrs.effort_name == nil
      assert attrs.duration_minutes == 160
      assert attrs.distance_kms == 5.5
      assert attrs.observers == "1"
      assert attrs.ebird_complete == true
      assert attrs.import_source == :ebird
    end

    test "a casual observation with no time or duration" do
      assert {:ok, attrs} =
               Converter.checklist_attrs(
                 row(%{
                   "Protocol" => "eBird - Casual Observation",
                   "Time" => "",
                   "Duration (Min)" => "0",
                   "All Obs Reported" => "0",
                   "Distance Traveled (km)" => ""
                 })
               )

      assert attrs.effort_type == "INCIDENTAL"
      assert attrs.start_time == nil
      assert attrs.duration_minutes == 0
      assert attrs.distance_kms == nil
      assert attrs.ebird_complete == false
    end

    test "an unrecognized protocol maps to OTHER, keeping the protocol as effort_name" do
      assert {:ok, attrs} =
               Converter.checklist_attrs(row(%{"Protocol" => "eBird - Rocket Science"}))

      assert attrs.effort_type == "OTHER"
      assert attrs.effort_name == "eBird - Rocket Science"
    end

    test "a blank protocol leaves the effort untyped" do
      assert {:ok, attrs} = Converter.checklist_attrs(row(%{"Protocol" => ""}))
      assert attrs.effort_type == nil
      assert attrs.effort_name == nil
    end

    test "area is converted from hectares to acres" do
      assert {:ok, attrs} = Converter.checklist_attrs(row(%{"Area Covered (ha)" => "10"}))
      assert_in_delta attrs.area_acres, 24.7105, 0.0001
    end

    test "a blank Submission ID is an invalid row" do
      assert Converter.checklist_attrs(row(%{"Submission ID" => ""})) ==
               {:error, :missing_submission_id}
    end
  end

  describe "observation_attrs/1" do
    test "carries the raw scientific name for the caller to resolve" do
      attrs = Converter.observation_attrs(row(%{}))

      assert attrs.name_sci == "Dendrocygna autumnalis"
      assert attrs.quantity == "5"
      assert attrs.ml_catalog_numbers == ["130552881"]
      assert attrs.import_source == :ebird
    end

    test "count of X (present, uncounted) passes through" do
      assert Converter.observation_attrs(row(%{"Count" => "X"})).quantity == "X"
    end

    test "multiple ML catalog numbers split on whitespace" do
      attrs = Converter.observation_attrs(row(%{"ML Catalog Numbers" => "111 222 333"}))
      assert attrs.ml_catalog_numbers == ["111", "222", "333"]
    end

    test "no ML catalog numbers is an empty list" do
      assert Converter.observation_attrs(row(%{"ML Catalog Numbers" => ""})).ml_catalog_numbers ==
               []
    end
  end

  describe "breeding_code/1" do
    test "keeps only the code from '<code> <text>'" do
      assert Converter.breeding_code("CF Carrying Food") == "CF"
      assert Converter.breeding_code("S7 Singing Bird Present 7+ Days") == "S7"
    end

    test "a blank cell is nil" do
      assert Converter.breeding_code("") == nil
      assert Converter.breeding_code(nil) == nil
    end

    test "observation_attrs splits the breeding code" do
      attrs = Converter.observation_attrs(row(%{"Breeding Code" => "ON Occupied Nest"}))
      assert attrs.breeding_code == "ON"
    end
  end
end
