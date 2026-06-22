defmodule Kjogvi.Geo.ImportTest do
  use Kjogvi.DataCase, async: false

  # The import's telemetry handler logs an error on each deliberate failure-path
  # test (`:missing_parent`); capture it so it only surfaces when a test actually
  # fails.
  @moduletag :capture_log

  alias Kjogvi.Geo.Import
  alias Kjogvi.Geo.Location
  alias Kjogvi.Repo

  # Writes the given rows (maps) as a JSONL file in the test's tmp dir and
  # returns its path.
  defp write_jsonl(rows) do
    path =
      Path.join(System.tmp_dir!(), "iso_3166_test_#{System.unique_integer([:positive])}.jsonl")

    File.write!(path, jsonl(rows))
    on_exit(fn -> File.rm(path) end)
    path
  end

  # Renders rows (maps) as a JSONL string body, as a fetched URL would return.
  defp jsonl(rows) do
    Enum.map_join(rows, "\n", &Jason.encode!/1) <> "\n"
  end

  # A `Req` plug option that serves `body` for any request, so the URL form of
  # `import/2` can be exercised without hitting the network.
  defp serving(body) do
    [plug: fn conn -> Plug.Conn.send_resp(conn, 200, body) end]
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

  describe "import/2 from a local path" do
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
      # Bulk insert sets timestamps explicitly (it bypasses the changeset).
      assert %DateTime{} = country.inserted_at
      assert %DateTime{} = country.updated_at
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

    test "runs against a non-empty table, adding new locations" do
      insert(:country, iso_code: "US")

      path = write_jsonl([country_row("UA", "Ukraine")])

      assert {:ok, _} = Import.import(path)
      assert by_iso("UA").location_type == :country
    end

    test "imported locations take ids in the reserved upper range" do
      path = write_jsonl([country_row("UA", "Ukraine")])

      assert {:ok, _} = Import.import(path)

      assert by_iso("UA").id >= 10_000
    end
  end

  describe "re-running the import (upsert on iso_code)" do
    test "updates an existing country in place instead of duplicating it" do
      assert {:ok, _} = Import.import(write_jsonl([country_row("UA", "Ukraine")]))
      original = by_iso("UA")

      assert {:ok, _} =
               Import.import(write_jsonl([country_row("UA", "Ukraine (renamed)")]))

      updated = by_iso("UA")
      assert updated.id == original.id
      assert updated.name_en == "Ukraine (renamed)"
      assert Repo.aggregate(Location, :count) == 1
    end

    test "refreshes provenance extras on a re-run" do
      assert {:ok, _} = Import.import(write_jsonl([country_row("UA", "Ukraine")]))

      assert {:ok, _} =
               Import.import(
                 write_jsonl([
                   country_row("UA", "Ukraine", %{"iso_codes_version" => "5.0.0"})
                 ])
               )

      assert by_iso("UA").extras["iso_codes_version"] == "5.0.0"
    end

    test "re-points a subdivision's country_id to the existing country" do
      seed = [country_row("UA", "Ukraine"), subdivision_row("UA-30", "Kyiv City", "UA")]
      assert {:ok, _} = Import.import(write_jsonl(seed))
      country_id = by_iso("UA").id

      assert {:ok, _} = Import.import(write_jsonl(seed))

      assert by_iso("UA-30").country_id == country_id
      assert Repo.aggregate(Location, :count) == 2
    end

    test "preserves user-editable columns the import does not own" do
      assert {:ok, _} = Import.import(write_jsonl([country_row("UA", "Ukraine")]))

      by_iso("UA")
      |> Ecto.Changeset.change(is_private: true, slug: "custom_slug")
      |> Repo.update!()

      assert {:ok, _} =
               Import.import(write_jsonl([country_row("UA", "Ukraine (renamed)")]))

      updated = by_iso("UA")
      assert updated.name_en == "Ukraine (renamed)"
      assert updated.is_private == true
      assert updated.slug == "custom_slug"
    end
  end

  describe "import/2 from a URL" do
    test "imports the JSONL fetched from an http(s) URL" do
      body = jsonl([country_row("UA", "Ukraine"), subdivision_row("UA-30", "Kyiv City", "UA")])

      assert {:ok, _} =
               Import.import("https://example.test/iso.jsonl", req_options: serving(body))

      assert by_iso("UA-30").country_id == by_iso("UA").id
    end

    test "raises when no source is given and no URL is configured" do
      assert is_nil(Import.default_url())

      assert_raise RuntimeError, ~r/URL is not configured/, fn ->
        Import.import()
      end
    end
  end

  describe "country_exists?/0" do
    test "is false on an empty table and true once a country is present" do
      refute Import.country_exists?()

      insert(:country, iso_code: "US")

      assert Import.country_exists?()
    end
  end

  describe "telemetry" do
    # Forwards each named import span event (`:start` / `:stop`) to the test
    # process, tagged with its suffix so a test can assert on either.
    defp attach_handlers(suffixes) do
      ref = make_ref()
      test_pid = self()
      events = Enum.map(suffixes, &[:kjogvi, :geo, :import, &1])

      :telemetry.attach_many(
        {__MODULE__, ref},
        events,
        fn [:kjogvi, :geo, :import, suffix], measurements, metadata, _ ->
          send(test_pid, {:telemetry, suffix, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach({__MODULE__, ref}) end)
    end

    test "emits start then stop with the duration and inserted count on success" do
      attach_handlers([:start, :stop])

      path = write_jsonl([country_row("UA", "Ukraine"), subdivision_row("UA-30", "Kyiv", "UA")])
      assert {:ok, _} = Import.import(path)

      assert_received {:telemetry, :start, %{system_time: _}, _}
      assert_received {:telemetry, :stop, %{duration: duration}, %{result: :ok, count: 2}}
      assert is_integer(duration) and duration > 0
    end

    test "emits a stop event carrying the failure reason" do
      attach_handlers([:stop])

      path =
        write_jsonl([
          country_row("UA", "Ukraine"),
          subdivision_row("ZZ-01", "Nowhere", "ZZ")
        ])

      assert {:error, {:missing_parent, "ZZ-01", "ZZ"}} = Import.import(path)

      assert_received {:telemetry, :stop, %{duration: _},
                       %{result: :error, reason: {:missing_parent, "ZZ-01", "ZZ"}}}
    end
  end
end
