defmodule KjogviWeb.Live.My.Checklists.ShowTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures

  setup %{conn: conn} do
    user = user_fixture()
    %{conn: login_user(conn, user), user: user}
  end

  test "renders breadcrumbs with link to checklists index", %{conn: conn, user: user} do
    checklist = insert(:checklist, user: user)

    {:ok, show_live, _html} = live(conn, ~p"/my/checklists/#{checklist.id}")

    assert has_element?(show_live, "#checklist-breadcrumbs")
    assert has_element?(show_live, "#checklist-breadcrumbs a", "Checklists")
  end

  test "renders with no observations", %{conn: conn, user: user} do
    checklist = insert(:checklist, user: user)

    {:ok, _show_live, html} = live(conn, ~p"/my/checklists/#{checklist.id}")

    assert html =~ "Checklist ##{checklist.id}"
    assert html =~ "This checklist has no observations."
  end

  test "shows an unresolved marker for unresolved checklists", %{conn: conn, user: user} do
    checklist = insert(:checklist, user: user, resolved: false)

    {:ok, show_live, _html} = live(conn, ~p"/my/checklists/#{checklist.id}")

    assert has_element?(show_live, "#checklist-unresolved")
  end

  test "has no unresolved marker for resolved checklists", %{conn: conn, user: user} do
    checklist = insert(:checklist, user: user, resolved: true)

    {:ok, show_live, _html} = live(conn, ~p"/my/checklists/#{checklist.id}")

    refute has_element?(show_live, "#checklist-unresolved")
  end

  test "renders an edit link", %{conn: conn, user: user} do
    checklist = insert(:checklist, user: user)

    {:ok, show_live, _html} = live(conn, ~p"/my/checklists/#{checklist.id}")

    assert has_element?(show_live, ~s{a[href="/my/checklists/#{checklist.id}/edit"]})
  end

  test "renders an eBird link when ebird_id is present", %{conn: conn, user: user} do
    checklist = insert(:checklist, user: user, ebird_id: "S100803884")

    {:ok, show_live, _html} = live(conn, ~p"/my/checklists/#{checklist.id}")

    assert has_element?(
             show_live,
             ~s{a[href="https://ebird.org/checklist/S100803884"]}
           )
  end

  test "renders eBird details panel when ebird_id is present", %{conn: conn, user: user} do
    checklist = insert(:checklist, user: user, ebird_id: "S100803884")

    {:ok, show_live, _html} = live(conn, ~p"/my/checklists/#{checklist.id}")

    assert has_element?(show_live, "#checklist-ebird-details", "S100803884")

    assert has_element?(
             show_live,
             ~s{#checklist-ebird-details a[href="https://ebird.org/checklist/S100803884"]}
           )
  end

  test "does not render eBird details panel when ebird_id is absent", %{conn: conn, user: user} do
    checklist = insert(:checklist, user: user, ebird_id: nil)

    {:ok, show_live, _html} = live(conn, ~p"/my/checklists/#{checklist.id}")

    refute has_element?(show_live, "#checklist-ebird-details")
  end

  test "eBird panel shows Complete badge when ebird_complete is true", %{conn: conn, user: user} do
    checklist = insert(:checklist, user: user, ebird_id: "S1", ebird_complete: true)

    {:ok, show_live, _html} = live(conn, ~p"/my/checklists/#{checklist.id}")

    assert has_element?(show_live, "#checklist-ebird-details", "Complete")
    refute has_element?(show_live, "#checklist-ebird-details", "Incomplete")
  end

  test "eBird panel shows Incomplete badge when ebird_complete is false", %{
    conn: conn,
    user: user
  } do
    checklist = insert(:checklist, user: user, ebird_id: "S1", ebird_complete: false)

    {:ok, show_live, _html} = live(conn, ~p"/my/checklists/#{checklist.id}")

    assert has_element?(show_live, "#checklist-ebird-details", "Incomplete")
  end

  test "eBird panel shows no badge when ebird_complete is nil", %{conn: conn, user: user} do
    checklist = insert(:checklist, user: user, ebird_id: "S1", ebird_complete: nil)

    {:ok, show_live, _html} = live(conn, ~p"/my/checklists/#{checklist.id}")

    refute has_element?(show_live, "#checklist-ebird-details", "Complete")
    refute has_element?(show_live, "#checklist-ebird-details", "Incomplete")
  end

  test "shows completeness badge in details panel when ebird_id absent but complete set", %{
    conn: conn,
    user: user
  } do
    checklist = insert(:checklist, user: user, ebird_id: nil, ebird_complete: false)

    {:ok, show_live, html} = live(conn, ~p"/my/checklists/#{checklist.id}")

    # No separate eBird panel section, but the badge appears in the page body.
    refute has_element?(show_live, "#checklist-ebird-details")
    assert html =~ "Incomplete"
  end

  test "no completeness badge when both ebird_id and ebird_complete are absent", %{
    conn: conn,
    user: user
  } do
    checklist = insert(:checklist, user: user, ebird_id: nil, ebird_complete: nil)

    {:ok, show_live, html} = live(conn, ~p"/my/checklists/#{checklist.id}")

    refute has_element?(show_live, "#checklist-ebird-details")
    refute html =~ "Incomplete"
    refute html =~ "Complete"
  end

  test "renders with observations present", %{conn: conn, user: user} do
    checklist = insert(:checklist, user: user)
    taxon = Ornitho.Factory.insert(:taxon, category: "spuh")
    insert(:observation, checklist: checklist, taxon_key: Ornitho.Schema.Taxon.key(taxon))

    {:ok, show_live, html} = live(conn, ~p"/my/checklists/#{checklist.id}")

    assert html =~ "Checklist ##{checklist.id}"
    assert has_element?(show_live, "#observation")
  end

  test "deletes a checklist with no observations and navigates to index", %{
    conn: conn,
    user: user
  } do
    checklist = insert(:checklist, user: user)

    {:ok, show_live, _html} = live(conn, ~p"/my/checklists/#{checklist.id}")

    assert {:error, {:live_redirect, %{to: "/my/checklists"}}} =
             show_live
             |> element("#delete-checklist")
             |> render_click()

    refute Kjogvi.Repo.get(Kjogvi.Birding.Checklist, checklist.id)
  end

  test "delete control is inert when checklist has observations", %{conn: conn, user: user} do
    checklist = insert(:checklist, user: user)
    taxon = Ornitho.Factory.insert(:taxon, category: "spuh")
    insert(:observation, checklist: checklist, taxon_key: Ornitho.Schema.Taxon.key(taxon))

    {:ok, show_live, _html} = live(conn, ~p"/my/checklists/#{checklist.id}")

    # Rendered as a plain <span>, not a clickable button: no phx-click wiring.
    assert has_element?(show_live, "span#delete-checklist")
    refute has_element?(show_live, "#delete-checklist[phx-click]")
  end

  test "shows an import source note when import_source is present", %{conn: conn, user: user} do
    checklist = insert(:checklist, user: user, import_source: :ebird)

    {:ok, show_live, _html} = live(conn, ~p"/my/checklists/#{checklist.id}")

    assert has_element?(show_live, "#checklist-import-source", "Imported from: eBird")
  end

  test "shows no import source note when import_source is nil", %{conn: conn, user: user} do
    checklist = insert(:checklist, user: user, import_source: nil)

    {:ok, show_live, _html} = live(conn, ~p"/my/checklists/#{checklist.id}")

    refute has_element?(show_live, "#checklist-import-source")
  end

  test "does not render for wrong user", %{conn: conn} do
    checklist = insert(:checklist, user: user_fixture())
    taxon = Ornitho.Factory.insert(:taxon, category: "spuh")
    insert(:observation, checklist: checklist, taxon_key: Ornitho.Schema.Taxon.key(taxon))

    assert_raise Ecto.NoResultsError, fn ->
      live(conn, ~p"/my/checklists/#{checklist.id}")
    end
  end

  test "renders with unknown taxon", %{conn: conn, user: user} do
    checklist = insert(:checklist, user: user)
    insert(:observation, checklist: checklist, taxon_key: "/ioc/v1/pasdom")

    {:ok, _show_live, html} = live(conn, ~p"/my/checklists/#{checklist.id}")

    assert html =~ "Checklist ##{checklist.id}"
    assert html =~ "Undefined taxon!"
  end

  test "alerts when a countable taxon has no species page", %{conn: conn, user: user} do
    checklist = insert(:checklist, user: user)
    # A real species taxon, but never promoted to a species page.
    taxon = Ornitho.Factory.insert(:taxon, category: "species")
    obs = insert(:observation, checklist: checklist, taxon_key: Ornitho.Schema.Taxon.key(taxon))

    {:ok, show_live, _html} = live(conn, ~p"/my/checklists/#{checklist.id}")

    assert has_element?(show_live, "#observation-#{obs.id}-no-species-page")
  end

  test "no alert when a countable taxon has a species page", %{conn: conn, user: user} do
    checklist = insert(:checklist, user: user)
    {taxon, _page} = Kjogvi.Factory.create_species_taxon_with_page()
    obs = insert(:observation, checklist: checklist, taxon_key: Ornitho.Schema.Taxon.key(taxon))

    {:ok, show_live, _html} = live(conn, ~p"/my/checklists/#{checklist.id}")

    refute has_element?(show_live, "#observation-#{obs.id}-no-species-page")
  end

  test "no alert for a non-countable taxon without a species page", %{conn: conn, user: user} do
    checklist = insert(:checklist, user: user)
    taxon = Ornitho.Factory.insert(:taxon, category: "spuh")
    obs = insert(:observation, checklist: checklist, taxon_key: Ornitho.Schema.Taxon.key(taxon))

    {:ok, show_live, _html} = live(conn, ~p"/my/checklists/#{checklist.id}")

    refute has_element?(show_live, "#observation-#{obs.id}-no-species-page")
  end

  describe "effort badge" do
    test "shows NFC with a full-name title for nocturnal flight call", %{conn: conn, user: user} do
      checklist = insert(:checklist, user: user, effort_type: "NOCTURNAL_FLIGHT_CALL")

      {:ok, show_live, _html} = live(conn, ~p"/my/checklists/#{checklist.id}")

      assert has_element?(
               show_live,
               ~s{span[title="Effort type: Nocturnal flight call"]},
               "NFC"
             )
    end

    test "OTHER badge titles with the effort name", %{conn: conn, user: user} do
      checklist =
        insert(:checklist, user: user, effort_type: "OTHER", effort_name: "Big Sit")

      {:ok, show_live, _html} = live(conn, ~p"/my/checklists/#{checklist.id}")

      assert has_element?(show_live, ~s{span[title="Effort type: Big Sit"]}, "OTHER")
    end

    test "other types title with their label", %{conn: conn, user: user} do
      checklist = insert(:checklist, user: user, effort_type: "TRAVEL")

      {:ok, show_live, _html} = live(conn, ~p"/my/checklists/#{checklist.id}")

      assert has_element?(show_live, ~s{span[title="Effort type: Traveling"]}, "Traveling")
    end

    test "no badge when effort_type is nil", %{conn: conn, user: user} do
      checklist = insert(:checklist, user: user, effort_type: nil)

      {:ok, show_live, _html} = live(conn, ~p"/my/checklists/#{checklist.id}")

      refute has_element?(show_live, ~s{span[title^="Effort type:"]})
    end
  end
end
