defmodule Kjogvi.Geo.ImportTest do
  use Kjogvi.DataCase, async: true

  alias Kjogvi.Geo.Import
  alias Kjogvi.Geo.Location
  alias Kjogvi.Repo

  # Writes the given rows (maps) as a JSONL file in the test's tmp dir and
  # returns its path.
  defp write_jsonl(rows) do
    path =
      Path.join(System.tmp_dir!(), "iso_3166_test_#{System.unique_integer([:positive])}.jsonl")

    File.write!(path, Enum.map_join(rows, "\n", &Jason.encode!/1) <> "\n")
    on_exit(fn -> File.rm(path) end)
    path
  end

  defp country_row(iso, name, attrs \\ %{}) do
    Map.merge(
      %{
        "type" => "country",
        "iso_code" => iso,
        "name_en" => name,
        "parent_iso" => nil,
        "iso_codes_version" => "4.20.1"
      },
      attrs
    )
  end

  defp subdivision_row(iso, name, parent_iso) do
    %{
      "type" => "subdivision1",
      "iso_code" => iso,
      "name_en" => name,
      "parent_iso" => parent_iso,
      "iso_codes_version" => "4.20.1"
    }
  end

  defp by_iso(iso) do
    Repo.get_by!(Location, iso_code: iso)
  end

  describe "import/1" do
    test "imports a country as a top-level common location" do
      path = write_jsonl([country_row("UA", "Ukraine", %{"numeric" => "804"})])

      assert {:ok, _} = Import.import(path)

      country = by_iso("UA")
      assert country.location_type == :country
      assert country.name_en == "Ukraine"
      assert country.slug == "ua"
      assert country.is_private == false
      # Common location: not owned by any user.
      assert is_nil(country.user_id)
      # A country has no level FKs.
      assert Location.ancestor_ids(country) == []
    end

    test "derives the subdivision's level FKs from its country" do
      path =
        write_jsonl([
          country_row("UA", "Ukraine"),
          subdivision_row("UA-30", "Kyiv City", "UA")
        ])

      assert {:ok, _} = Import.import(path)

      country = by_iso("UA")
      subdivision = by_iso("UA-30")

      assert subdivision.location_type == :subdivision1
      assert subdivision.slug == "ua_30"
      assert subdivision.country_id == country.id
      assert Location.parent_id_from_levels(subdivision) == country.id
    end

    test "stores provenance in extras" do
      path =
        write_jsonl([
          country_row("AF", "Afghanistan", %{
            "official_name" => "Islamic Republic of Afghanistan",
            "numeric" => "004"
          })
        ])

      assert {:ok, _} = Import.import(path)

      country = by_iso("AF")
      assert country.extras["official_name"] == "Islamic Republic of Afghanistan"
      assert country.extras["numeric"] == "004"
      assert country.extras["iso_codes_version"] == "4.20.1"
      assert is_binary(country.extras["imported_at"])
    end

    test "rolls back the whole import when a parent is missing" do
      path =
        write_jsonl([
          country_row("UA", "Ukraine"),
          # Parent "ZZ" was never inserted.
          subdivision_row("ZZ-01", "Nowhere", "ZZ")
        ])

      assert {:error, {:missing_parent, "ZZ-01", "ZZ"}} = Import.import(path)
      # Nothing is committed — the earlier country is rolled back too.
      assert Repo.aggregate(Location, :count) == 0
    end
  end
end
