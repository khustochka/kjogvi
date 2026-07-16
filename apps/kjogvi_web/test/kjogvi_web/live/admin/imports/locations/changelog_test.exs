defmodule KjogviWeb.Live.Admin.Imports.Locations.ChangelogTest do
  # Not async: the apply runs in a LiveView `start_async` task, which needs the
  # shared (non-async) sandbox connection to see the test's data.
  use KjogviWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Kjogvi.Geo.Changelog
  alias Kjogvi.Geo.Location
  alias Kjogvi.Repo

  # Points the dataset storage at a scratch directory for the duration of a
  # test (the changelog is read from there).
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

  # Writes the changelog under its fixed storage key.
  defp write_source(ops) do
    jsonl = ops |> Enum.map_join("\n", &Jason.encode!/1)
    assert :ok = Kjogvi.Datasets.write(Changelog.source_key(), jsonl)
  end

  defp ops do
    [
      %{"iso_code" => "BO", "op" => "update", "fields" => %{"name_en" => "Bolivia"}},
      %{
        "iso_code" => "US-PR",
        "op" => "update",
        "fields" => %{"disabled" => true},
        "note" => "PR country instead"
      }
    ]
  end

  defp login_admin(conn) do
    login_user(conn, Kjogvi.AccountsFixtures.admin_fixture())
  end

  describe "preconditions" do
    test "shows a no-source notice when the changelog is missing", %{conn: conn} do
      {:ok, lv, _html} = conn |> login_admin() |> live(~p"/admin/imports/locations")

      assert has_element?(lv, "#changelog-apply-no-source")
      refute has_element?(lv, "#changelog-apply-form")
    end

    test "shows the apply button when a changelog exists", %{conn: conn} do
      write_source(ops())

      {:ok, lv, _html} = conn |> login_admin() |> live(~p"/admin/imports/locations")

      assert has_element?(lv, "#changelog-apply-form button", "Apply")
    end

    test "offers the apply button even once locations are curated", %{conn: conn} do
      write_source(ops())
      insert(:country, iso_code: "BO", name_en: "Bolivia")

      {:ok, lv, _html} = conn |> login_admin() |> live(~p"/admin/imports/locations")

      assert has_element?(lv, "#changelog-apply-form button", "Apply")
    end
  end

  describe "applying the changelog" do
    test "applies and reports the count with skipped codes", %{conn: conn} do
      write_source(ops())
      insert(:country, iso_code: "BO", name_en: "Bolivia, Plurinational State of")

      {:ok, lv, _html} = conn |> login_admin() |> live(~p"/admin/imports/locations")

      lv
      |> element("#changelog-apply-form")
      |> render_submit()

      # Wait for the start_async apply task to complete and the component to
      # re-render with the result flash.
      html = render_async(lv)

      assert html =~ "Applied changes to 1 locations."
      assert html =~ "Skipped 1 (not found): US-PR."
      assert Repo.get_by!(Location, iso_code: "BO").name_en == "Bolivia"
    end

    test "stays available for a re-run after applying", %{conn: conn} do
      write_source(ops())
      insert(:country, iso_code: "BO", name_en: "Bolivia, Plurinational State of")

      {:ok, lv, _html} = conn |> login_admin() |> live(~p"/admin/imports/locations")

      lv |> element("#changelog-apply-form") |> render_submit()
      render_async(lv)

      assert has_element?(lv, "#changelog-apply-form button", "Apply")
    end
  end
end
