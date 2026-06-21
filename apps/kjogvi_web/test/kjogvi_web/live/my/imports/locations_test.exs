defmodule KjogviWeb.Live.My.Imports.LocationsTest do
  # Not async: the import runs in a LiveView `start_async` task, which needs the
  # shared (non-async) sandbox connection to see the test's data.
  use KjogviWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Kjogvi.Geo.Location
  alias Kjogvi.Repo

  # Points the importer at a local JSONL file for the duration of a test. The
  # importer dispatches non-`http` sources to the file path branch, so this
  # exercises the full import flow without any network.
  defp configure_url(rows) do
    path = Path.join(System.tmp_dir!(), "iso_test_#{System.unique_integer([:positive])}.jsonl")
    File.write!(path, Enum.map_join(rows, "\n", &Jason.encode!/1) <> "\n")

    previous = Application.get_env(:kjogvi, Kjogvi.Geo.Import)
    Application.put_env(:kjogvi, Kjogvi.Geo.Import, url: path)

    on_exit(fn ->
      File.rm(path)
      Application.put_env(:kjogvi, Kjogvi.Geo.Import, previous || [])
    end)
  end

  defp country_row(iso, name) do
    %{"type" => "country", "iso_code" => iso, "name_en" => name, "parent_iso" => nil}
  end

  defp login_admin(conn) do
    login_user(conn, Kjogvi.AccountsFixtures.admin_fixture())
  end

  describe "visibility" do
    test "an admin sees the Locations Import card", %{conn: conn} do
      {:ok, _lv, html} = conn |> login_admin() |> live(~p"/my/imports")

      assert html =~ "Locations Import"
    end

    test "a non-admin does not see the Locations Import card", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> login_user(Kjogvi.AccountsFixtures.user_fixture())
        |> live(~p"/my/imports")

      refute html =~ "Locations Import"
    end
  end

  describe "preconditions" do
    test "shows an unconfigured notice when no URL is set", %{conn: conn} do
      # No LOCATIONS_IMPORT_URL configured in the test env.
      {:ok, lv, _html} = conn |> login_admin() |> live(~p"/my/imports")

      assert has_element?(lv, "#locations-import-unconfigured")
      refute has_element?(lv, "#locations-import-form")
    end

    test "shows the import button when a URL is configured and the table is empty",
         %{conn: conn} do
      configure_url([country_row("UA", "Ukraine")])

      {:ok, lv, _html} = conn |> login_admin() |> live(~p"/my/imports")

      assert has_element?(lv, "#locations-import-form")
      refute has_element?(lv, "#locations-import-done")
    end

    test "shows an already-imported notice when a country exists", %{conn: conn} do
      configure_url([country_row("UA", "Ukraine")])
      insert(:country, iso_code: "US")

      {:ok, lv, _html} = conn |> login_admin() |> live(~p"/my/imports")

      assert has_element?(lv, "#locations-import-done")
      refute has_element?(lv, "#locations-import-form")
    end
  end

  describe "running the import" do
    test "imports and reports the counts", %{conn: conn} do
      configure_url([
        country_row("UA", "Ukraine"),
        %{
          "type" => "subdivision1",
          "iso_code" => "UA-30",
          "name_en" => "Kyiv",
          "parent_iso" => "UA"
        }
      ])

      {:ok, lv, _html} = conn |> login_admin() |> live(~p"/my/imports")

      lv
      |> element("#locations-import-form")
      |> render_submit()

      # Wait for the start_async import task to complete and the component to
      # re-render with the result flash.
      html = render_async(lv)

      assert html =~ "Imported 1 countries and 1 subdivisions."
      assert Repo.aggregate(Location, :count) == 2
      # Once imported, the button is replaced by the already-imported notice.
      assert has_element?(lv, "#locations-import-done")
    end
  end
end
