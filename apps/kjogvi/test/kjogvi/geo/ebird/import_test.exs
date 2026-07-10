defmodule Kjogvi.Geo.Ebird.ImportTest do
  use Kjogvi.DataCase, async: false

  @moduletag :capture_log

  alias Kjogvi.Geo.Ebird.Import
  alias Kjogvi.Geo.EbirdLocation
  alias Kjogvi.Repo

  # Writes `entries` (a map of code => attrs, eBird dump style) as a scratch
  # JSON file and returns its path.
  defp write_json(entries) do
    path =
      Path.join(System.tmp_dir!(), "ebird_locs_test_#{System.unique_integer([:positive])}.json")

    File.write!(path, Jason.encode!(entries))
    on_exit(fn -> File.rm(path) end)
    path
  end

  defp entries do
    %{
      "AD" => %{
        "countryCode" => "AD",
        "localAbbrev" => "AD",
        "name" => "Andorra",
        "nameLong" => "Principality of Andorra",
        "nameShort" => "",
        "niceName" => "Andorra (AD)"
      },
      "AD-02" => %{
        "countryCode" => "AD",
        "localAbbrev" => "02",
        "name" => "Canillo",
        "niceName" => "Canillo, Andorra (AD)",
        "subnational1Code" => "AD-02"
      },
      "CA-AB-EI" => %{
        "countryCode" => "CA",
        "name" => "Red Deer",
        "niceName" => "Red Deer, Alberta, Canada (CA)",
        "subnational1Code" => "CA-AB",
        "subnational2Code" => "CA-AB-EI"
      },
      "aba" => %{"name" => "ABA"}
    }
  end

  test "imports regions with types derived from the code fields" do
    assert {:ok, %{count: 3}} = entries() |> write_json() |> Import.from_json()

    country = Repo.get_by!(EbirdLocation, code: "AD")
    assert country.location_type == :country
    assert country.country_code == "AD"
    assert country.name == "Andorra"
    assert country.name_long == "Principality of Andorra"
    # Empty strings are stored as nil.
    assert country.name_short == nil
    assert country.nice_name == "Andorra (AD)"
    assert country.local_abbrev == "AD"

    sub1 = Repo.get_by!(EbirdLocation, code: "AD-02")
    assert sub1.location_type == :subdivision1
    assert sub1.subnational1_code == "AD-02"
    assert sub1.subnational2_code == nil

    sub2 = Repo.get_by!(EbirdLocation, code: "CA-AB-EI")
    assert sub2.location_type == :subdivision2
    assert sub2.country_code == "CA"
    assert sub2.subnational1_code == "CA-AB"
    assert sub2.subnational2_code == "CA-AB-EI"
  end

  test "skips entries without a countryCode and reports them" do
    assert {:ok, %{count: 3, skipped: ["aba"]}} =
             entries() |> write_json() |> Import.from_json()

    refute Repo.get_by(EbirdLocation, code: "aba")
  end

  test "re-running refreshes names but never touches the match state" do
    assert {:ok, _} = entries() |> write_json() |> Import.from_json()

    location = insert(:country, iso_code: "AD")

    Repo.get_by!(EbirdLocation, code: "AD")
    |> Ecto.Changeset.change(location_id: location.id)
    |> Repo.update!()

    renamed = put_in(entries()["AD"]["name"], "Andorra Renamed")
    assert {:ok, %{count: 3}} = renamed |> write_json() |> Import.from_json()

    reimported = Repo.get_by!(EbirdLocation, code: "AD")
    assert reimported.name == "Andorra Renamed"
    assert reimported.location_id == location.id
    # Upserted in place, not duplicated.
    assert Repo.aggregate(EbirdLocation, :count) == 3
  end

  describe "import/0 through the configured storage" do
    setup do
      dir = Path.join(System.tmp_dir!(), "datasets_#{System.unique_integer([:positive])}")
      original = Application.get_env(:kjogvi, Kjogvi.Datasets)

      Application.put_env(:kjogvi, Kjogvi.Datasets,
        adapter: Kjogvi.Datasets.LocalAdapter,
        path: dir
      )

      on_exit(fn ->
        Application.put_env(:kjogvi, Kjogvi.Datasets, original)
        File.rm_rf(dir)
      end)

      :ok
    end

    test "imports the source JSON from the storage" do
      assert :ok = Kjogvi.Datasets.write(Import.source_key(), Jason.encode!(entries()))

      assert {:ok, %{count: 3, skipped: ["aba"]}} = Import.import()
      assert Repo.aggregate(EbirdLocation, :count) == 3
    end

    test "errors when no source file has been uploaded" do
      assert {:error, :enoent} = Import.import()
    end
  end

  test "emits a telemetry stop event with count and skipped codes" do
    ref = make_ref()
    test_pid = self()

    :telemetry.attach(
      {__MODULE__, ref},
      [:kjogvi, :geo, :ebird, :import, :stop],
      fn event, measurements, metadata, _ ->
        send(test_pid, {:telemetry, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach({__MODULE__, ref}) end)

    assert {:ok, _} = entries() |> write_json() |> Import.from_json()

    assert_received {:telemetry, [:kjogvi, :geo, :ebird, :import, :stop], %{duration: _},
                     %{result: :ok, count: 3, skipped: ["aba"]}}
  end
end
