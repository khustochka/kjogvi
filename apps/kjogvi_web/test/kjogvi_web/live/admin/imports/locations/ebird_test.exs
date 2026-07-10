defmodule KjogviWeb.Live.Admin.Imports.Locations.EbirdTest do
  # Not async: the import runs in a LiveView `start_async` task, which needs the
  # shared (non-async) sandbox connection to see the test's data.
  use KjogviWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Kjogvi.Geo.Ebird.Import
  alias Kjogvi.Geo.EbirdLocation
  alias Kjogvi.Repo

  # Points the dataset storage at a scratch directory for the duration of a
  # test (the importer reads its source JSON from there).
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

  # Writes the source JSON under the importer's fixed storage key.
  defp write_source(entries) do
    assert :ok = Kjogvi.Datasets.write(Import.source_key(), Jason.encode!(entries))
  end

  defp entries do
    %{
      "AD" => %{"countryCode" => "AD", "name" => "Andorra"},
      "AD-02" => %{"countryCode" => "AD", "name" => "Canillo", "subnational1Code" => "AD-02"},
      "aba" => %{"name" => "ABA"}
    }
  end

  defp login_admin(conn) do
    login_user(conn, Kjogvi.AccountsFixtures.admin_fixture())
  end

  describe "preconditions" do
    test "shows a no-source notice when the source file is missing", %{conn: conn} do
      {:ok, lv, _html} = conn |> login_admin() |> live(~p"/admin/imports/locations")

      assert has_element?(lv, "#ebird-import-no-source")
      refute has_element?(lv, "#ebird-import-form")
    end

    test "shows the import button when a source file exists and the table is empty",
         %{conn: conn} do
      write_source(entries())

      {:ok, lv, _html} = conn |> login_admin() |> live(~p"/admin/imports/locations")

      assert has_element?(lv, "#ebird-import-form button", "Import")
    end

    test "offers a re-import when eBird locations already exist", %{conn: conn} do
      write_source(entries())
      insert(:ebird_location)

      {:ok, lv, _html} = conn |> login_admin() |> live(~p"/admin/imports/locations")

      assert has_element?(lv, "#ebird-import-form button", "Re-import")
    end
  end

  describe "running the import" do
    test "imports and reports the count with skipped codes", %{conn: conn} do
      write_source(entries())

      {:ok, lv, _html} = conn |> login_admin() |> live(~p"/admin/imports/locations")

      lv
      |> element("#ebird-import-form")
      |> render_submit()

      # Wait for the start_async import task to complete and the component to
      # re-render with the result flash.
      html = render_async(lv)

      assert html =~ "Imported 2 eBird regions."
      assert html =~ "Skipped 1: aba."
      assert Repo.aggregate(EbirdLocation, :count) == 2
      # The import is re-runnable; the button stays, now labelled Re-import.
      assert has_element?(lv, "#ebird-import-form button", "Re-import")
    end
  end
end
