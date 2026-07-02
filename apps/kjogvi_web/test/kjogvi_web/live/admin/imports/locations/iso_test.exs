defmodule KjogviWeb.Live.Admin.Imports.Locations.IsoTest do
  # Not async: the import runs in a LiveView `start_async` task, which needs the
  # shared (non-async) sandbox connection to see the test's data.
  use KjogviWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Kjogvi.Geo.Import
  alias Kjogvi.Geo.Location
  alias Kjogvi.Repo

  # Points the dataset storage at a scratch directory for the duration of a
  # test (the importer reads its source JSONL from there).
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

  # Writes the source JSONL under the importer's fixed storage key.
  defp write_source(rows) do
    assert :ok =
             Kjogvi.Datasets.write(
               Import.source_key(),
               Enum.map_join(rows, "\n", &Jason.encode!/1) <> "\n"
             )
  end

  defp country_row(iso, name) do
    %{"type" => "country", "iso_code" => iso, "name_en" => name, "parent_iso" => nil}
  end

  defp login_admin(conn) do
    login_user(conn, Kjogvi.AccountsFixtures.admin_fixture())
  end

  describe "preconditions" do
    test "shows a no-source notice when the source file is missing", %{conn: conn} do
      {:ok, lv, _html} = conn |> login_admin() |> live(~p"/admin/imports/locations")

      assert has_element?(lv, "#locations-import-no-source")
      refute has_element?(lv, "#locations-import-form")
    end

    test "shows the import button when a source file exists and the table is empty",
         %{conn: conn} do
      write_source([country_row("UA", "Ukraine")])

      {:ok, lv, _html} = conn |> login_admin() |> live(~p"/admin/imports/locations")

      assert has_element?(lv, "#locations-import-form button", "Import")
    end

    test "offers a re-import when a country already exists", %{conn: conn} do
      write_source([country_row("UA", "Ukraine")])
      insert(:country, iso_code: "US")

      {:ok, lv, _html} = conn |> login_admin() |> live(~p"/admin/imports/locations")

      assert has_element?(lv, "#locations-import-form button", "Re-import")
    end
  end

  describe "running the import" do
    test "imports and reports the counts", %{conn: conn} do
      write_source([
        country_row("UA", "Ukraine"),
        %{
          "type" => "subdivision1",
          "iso_code" => "UA-30",
          "name_en" => "Kyiv",
          "parent_iso" => "UA"
        }
      ])

      {:ok, lv, _html} = conn |> login_admin() |> live(~p"/admin/imports/locations")

      lv
      |> element("#locations-import-form")
      |> render_submit()

      # Wait for the start_async import task to complete and the component to
      # re-render with the result flash.
      html = render_async(lv)

      assert html =~ "Imported 1 countries and 1 subdivisions."
      assert Repo.aggregate(Location, :count) == 2
      # The import is re-runnable; the button stays, now labelled Re-import.
      assert has_element?(lv, "#locations-import-form button", "Re-import")
    end
  end
end
