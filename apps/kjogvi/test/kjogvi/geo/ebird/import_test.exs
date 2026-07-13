defmodule Kjogvi.Geo.Ebird.ImportTest do
  use Kjogvi.DataCase, async: false

  @moduletag :capture_log

  alias Kjogvi.Geo.Ebird.Import
  alias Kjogvi.Geo.EbirdLocation
  alias Kjogvi.Repo

  # Writes `entries` (a list of eBird subregion objects) as a scratch JSONL
  # file and returns its path.
  defp write_jsonl(entries) do
    path =
      Path.join(System.tmp_dir!(), "ebird_locs_test_#{System.unique_integer([:positive])}.jsonl")

    File.write!(path, entries |> Enum.map_join("\n", &Jason.encode!/1))
    on_exit(fn -> File.rm(path) end)
    path
  end

  defp entries do
    [
      %{"code" => "AD", "name" => "Andorra", "level" => "country", "parent_code" => nil},
      %{"code" => "AD-02", "name" => "Canillo", "level" => "subregion1", "parent_code" => "AD"},
      %{
        "code" => "CA-AB-EI",
        "name" => "Red Deer",
        "level" => "subregion2",
        "parent_code" => "CA-AB"
      },
      %{"code" => "aba", "name" => "ABA", "level" => "custom", "parent_code" => nil}
    ]
  end

  test "imports regions with codes derived from the eBird code hierarchy" do
    assert {:ok, %{count: 3}} = entries() |> write_jsonl() |> Import.from_jsonl()

    country = Repo.get_by!(EbirdLocation, code: "AD")
    assert country.location_type == :country
    assert country.country_code == "AD"
    assert country.subnational1_code == nil
    assert country.name == "Andorra"

    sub1 = Repo.get_by!(EbirdLocation, code: "AD-02")
    assert sub1.location_type == :subdivision1
    assert sub1.country_code == "AD"
    assert sub1.subnational1_code == "AD-02"
    assert sub1.subnational2_code == nil

    sub2 = Repo.get_by!(EbirdLocation, code: "CA-AB-EI")
    assert sub2.location_type == :subdivision2
    assert sub2.country_code == "CA"
    assert sub2.subnational1_code == "CA-AB"
    assert sub2.subnational2_code == "CA-AB-EI"
  end

  test "skips entries with an unrecognized level and reports them" do
    assert {:ok, %{count: 3, skipped: ["aba"]}} =
             entries() |> write_jsonl() |> Import.from_jsonl()

    refute Repo.get_by(EbirdLocation, code: "aba")
  end

  test "re-running refreshes names but never touches the match state" do
    assert {:ok, _} = entries() |> write_jsonl() |> Import.from_jsonl()

    location = insert(:country, iso_code: "AD")

    Repo.get_by!(EbirdLocation, code: "AD")
    |> Ecto.Changeset.change(location_id: location.id)
    |> Repo.update!()

    renamed =
      Enum.map(entries(), fn
        %{"code" => "AD"} = entry -> %{entry | "name" => "Andorra Renamed"}
        entry -> entry
      end)

    assert {:ok, %{count: 3}} = renamed |> write_jsonl() |> Import.from_jsonl()

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

    test "imports the source JSONL from the storage" do
      jsonl = entries() |> Enum.map_join("\n", &Jason.encode!/1)
      assert :ok = Kjogvi.Datasets.write(Import.source_key(), jsonl)

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

    assert {:ok, _} = entries() |> write_jsonl() |> Import.from_jsonl()

    assert_received {:telemetry, [:kjogvi, :geo, :ebird, :import, :stop], %{duration: _},
                     %{result: :ok, count: 3, skipped: ["aba"]}}
  end
end
