defmodule Kjogvi.Geo.ChangelogTest do
  use Kjogvi.DataCase, async: false

  @moduletag :capture_log

  alias Kjogvi.Geo.Changelog
  alias Kjogvi.Geo.Location
  alias Kjogvi.Repo

  # Writes the given ops (maps) as a JSONL file in the test's tmp dir and
  # returns its path.
  defp write_jsonl(ops) do
    path =
      Path.join(System.tmp_dir!(), "changelog_test_#{System.unique_integer([:positive])}.jsonl")

    File.write!(path, Enum.map_join(ops, "\n", &Jason.encode!/1) <> "\n")
    on_exit(fn -> File.rm(path) end)
    path
  end

  defp update_op(iso_code, fields, extra \\ %{}) do
    Map.merge(%{"iso_code" => iso_code, "op" => "update", "fields" => fields}, extra)
  end

  test "applies each updatable field to the location with the matching iso_code" do
    insert(:country, iso_code: "BO", name_en: "Bolivia, Plurinational State of")
    insert(:country, iso_code: "RU", name_en: "Russian Federation")
    subdivision = insert(:subdivision1, iso_code: "US-PR")

    ops = [
      update_op("BO", %{"name_en" => "Bolivia"}),
      update_op("RU", %{"hide_flag" => true}),
      update_op("US-PR", %{"disabled" => true}, %{"note" => "PR country instead"})
    ]

    assert {:ok, %{count: 3, skipped: []}} = ops |> write_jsonl() |> Changelog.from_jsonl()

    assert Repo.get_by!(Location, iso_code: "BO").name_en == "Bolivia"
    assert Repo.get_by!(Location, iso_code: "RU").hide_flag
    assert Repo.get!(Location, subdivision.id).disabled
  end

  test "applies several fields named in one op" do
    insert(:country, iso_code: "XX", name_en: "Old Name")

    ops = [update_op("XX", %{"name_en" => "New Name", "disabled" => true})]

    assert {:ok, %{count: 1}} = ops |> write_jsonl() |> Changelog.from_jsonl()

    location = Repo.get_by!(Location, iso_code: "XX")
    assert location.name_en == "New Name"
    assert location.disabled
  end

  test "skips and reports iso_codes matching no location, applying the rest" do
    insert(:country, iso_code: "BO", name_en: "Bolivia, Plurinational State of")

    ops = [
      update_op("BO", %{"name_en" => "Bolivia"}),
      update_op("FR-CP", %{"disabled" => true}),
      update_op("XK", %{"disabled" => true})
    ]

    assert {:ok, %{count: 1, skipped: ["FR-CP", "XK"]}} =
             ops |> write_jsonl() |> Changelog.from_jsonl()

    assert Repo.get_by!(Location, iso_code: "BO").name_en == "Bolivia"
  end

  test "re-applying is a no-op" do
    insert(:country, iso_code: "BO", name_en: "Bolivia, Plurinational State of")
    path = write_jsonl([update_op("BO", %{"name_en" => "Bolivia"})])

    assert {:ok, %{count: 1}} = Changelog.from_jsonl(path)
    assert {:ok, %{count: 1, skipped: []}} = Changelog.from_jsonl(path)

    assert Repo.get_by!(Location, iso_code: "BO").name_en == "Bolivia"
  end

  test "leaves locations the changelog does not name untouched" do
    insert(:country, iso_code: "BO", name_en: "Bolivia, Plurinational State of")
    untouched = insert(:country, iso_code: "AD", name_en: "Andorra")

    assert {:ok, %{count: 1}} =
             [update_op("BO", %{"name_en" => "Bolivia"})]
             |> write_jsonl()
             |> Changelog.from_jsonl()

    reloaded = Repo.get!(Location, untouched.id)
    assert reloaded.name_en == "Andorra"
    refute reloaded.disabled
  end

  test "raises on a field the changelog may not update" do
    insert(:country, iso_code: "BO", name_en: "Bolivia, Plurinational State of")
    path = write_jsonl([update_op("BO", %{"slug" => "hijacked"})])

    assert_raise ArgumentError, ~r/cannot update "slug"/, fn ->
      Changelog.from_jsonl(path)
    end
  end

  describe "apply/0" do
    # Point the storage at an empty temp dir: the configured path resolves under
    # the app's priv dir, which holds the real curated changelog.
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

    test "reads the changelog from the datasets storage" do
      insert(:country, iso_code: "BO", name_en: "Bolivia, Plurinational State of")

      Kjogvi.Datasets.write(
        Changelog.source_key(),
        Jason.encode!(update_op("BO", %{"name_en" => "Bolivia"}))
      )

      assert {:ok, %{count: 1, skipped: []}} = Changelog.apply()
      assert Repo.get_by!(Location, iso_code: "BO").name_en == "Bolivia"
    end

    test "returns an error when no changelog has been uploaded" do
      assert {:error, :enoent} = Changelog.apply()
    end
  end
end
