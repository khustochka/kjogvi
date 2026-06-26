defmodule KjogviWeb.Live.My.Checklists.IndexTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures

  setup %{conn: conn} do
    user = user_fixture()
    %{conn: login_user(conn, user), user: user}
  end

  test "renders with no cards", %{conn: conn} do
    {:ok, index_live, _html} = live(conn, ~p"/my/cards")

    assert index_live
           |> element("h1", "Checklists")
           |> render()
  end

  test "renders a checklist as a panel with location", %{conn: conn, user: user} do
    checklist = insert(:checklist, user: user)

    {:ok, index_live, _html} = live(conn, ~p"/my/cards")

    assert has_element?(index_live, "#checklists")
    assert has_element?(index_live, "#checklist-#{checklist.id}")
    assert render(index_live) =~ "Winnipeg"
  end

  test "panel shows an unresolved marker for unresolved cards", %{conn: conn, user: user} do
    checklist = insert(:checklist, user: user, resolved: false)

    {:ok, index_live, _html} = live(conn, ~p"/my/cards")

    assert has_element?(index_live, "#checklist-#{checklist.id}-unresolved")
  end

  test "panel has no unresolved marker for resolved cards", %{conn: conn, user: user} do
    checklist = insert(:checklist, user: user, resolved: true)

    {:ok, index_live, _html} = live(conn, ~p"/my/cards")

    assert has_element?(index_live, "#checklist-#{checklist.id}")
    refute has_element?(index_live, "#checklist-#{checklist.id}-unresolved")
  end

  test "panel links to show, edit and counts", %{conn: conn, user: user} do
    {taxon, _page} = Kjogvi.Factory.create_species_taxon_with_page()
    key = Ornitho.Schema.Taxon.key(taxon)

    checklist = insert(:checklist, user: user)
    insert(:observation, checklist: checklist, taxon_key: key)
    insert(:observation, checklist: checklist, taxon_key: "ebird/eBird_2023/amecro")

    {:ok, index_live, _html} = live(conn, ~p"/my/cards")

    panel = element(index_live, "#checklist-#{checklist.id}")

    assert has_element?(
             index_live,
             ~s{#checklist-#{checklist.id} a[href="/my/cards/#{checklist.id}"]}
           )

    assert has_element?(
             index_live,
             ~s{#checklist-#{checklist.id} a[href="/my/cards/#{checklist.id}/edit"]},
             "Edit"
           )

    # 1 countable species, 2 distinct taxa, 2 observations.
    rendered = render(panel)
    assert rendered =~ "sp."
    assert rendered =~ "taxa"
    assert rendered =~ "obs"
  end

  test "panel does not list observations by default (checklist mode)", %{conn: conn, user: user} do
    {taxon, _page} = Kjogvi.Factory.create_species_taxon_with_page()
    key = Ornitho.Schema.Taxon.key(taxon)

    checklist = insert(:checklist, user: user)
    obs = insert(:observation, checklist: checklist, taxon_key: key)

    {:ok, index_live, _html} = live(conn, ~p"/my/cards")

    assert has_element?(index_live, "#checklist-#{checklist.id}")
    refute has_element?(index_live, "#checklist-#{checklist.id}-obs-#{obs.id}")
  end

  test "panel links to eBird checklist when ebird_id present", %{conn: conn, user: user} do
    checklist = insert(:checklist, user: user, ebird_id: "S100803884")

    {:ok, index_live, _html} = live(conn, ~p"/my/cards")

    assert has_element?(
             index_live,
             ~s{#checklist-#{checklist.id} a[href="https://ebird.org/checklist/S100803884"]}
           )
  end

  test "panel omits eBird link when ebird_id is absent", %{conn: conn, user: user} do
    checklist = insert(:checklist, user: user, ebird_id: nil)

    {:ok, index_live, _html} = live(conn, ~p"/my/cards")

    refute has_element?(
             index_live,
             ~s{#checklist-#{checklist.id} a[href^="https://ebird.org/checklist/"]}
           )
  end

  test "panel shows Complete badge when ebird_complete is true", %{conn: conn, user: user} do
    checklist = insert(:checklist, user: user, ebird_id: "S1", ebird_complete: true)

    {:ok, index_live, _html} = live(conn, ~p"/my/cards")

    assert has_element?(index_live, "#checklist-#{checklist.id}", "Complete")
  end

  test "panel shows Incomplete badge when ebird_complete is false", %{conn: conn, user: user} do
    checklist = insert(:checklist, user: user, ebird_id: "S1", ebird_complete: false)

    {:ok, index_live, _html} = live(conn, ~p"/my/cards")

    assert has_element?(index_live, "#checklist-#{checklist.id}", "Incomplete")
  end

  test "panel shows no completeness badge when ebird_complete is nil", %{conn: conn, user: user} do
    checklist = insert(:checklist, user: user, ebird_id: "S1", ebird_complete: nil)

    {:ok, index_live, html} = live(conn, ~p"/my/cards")

    panel = render(element(index_live, "#checklist-#{checklist.id}"))
    refute panel =~ "Complete"
    refute panel =~ "Incomplete"
    assert html =~ "S1"
  end

  test "panel shows completeness badge when ebird_id is absent", %{
    conn: conn,
    user: user
  } do
    checklist = insert(:checklist, user: user, ebird_id: nil, ebird_complete: true)

    {:ok, index_live, _html} = live(conn, ~p"/my/cards")

    assert has_element?(index_live, "#checklist-#{checklist.id}", "Complete")

    refute has_element?(
             index_live,
             ~s{#checklist-#{checklist.id} a[href^="https://ebird.org/checklist/"]}
           )
  end

  test "deletes a checklist with no observations", %{conn: conn, user: user} do
    checklist = insert(:checklist, user: user)

    {:ok, index_live, _html} = live(conn, ~p"/my/cards")

    assert index_live
           |> element("#delete-checklist-#{checklist.id}")
           |> render_click()

    refute has_element?(index_live, "#checklist-#{checklist.id}")
    refute Kjogvi.Repo.get(Kjogvi.Birding.Checklist, checklist.id)
  end

  test "delete control is inert for a checklist with observations", %{conn: conn, user: user} do
    checklist = insert(:checklist, user: user)
    insert(:observation, checklist: checklist, taxon_key: "ebird/eBird_2023/amecro")

    {:ok, index_live, _html} = live(conn, ~p"/my/cards")

    # Rendered as a plain <span>, not a clickable button: no phx-click wiring.
    assert has_element?(index_live, "span#delete-checklist-#{checklist.id}")
    refute has_element?(index_live, "#delete-checklist-#{checklist.id}[phx-click]")
  end

  test "pagination with multiple cards", %{conn: conn, user: user} do
    location = insert(:location)
    insert_list(21, :checklist, location: location, user: user)

    {:ok, _index_live, html} = live(conn, ~p"/my/cards")

    assert html =~ "/cards/page/2"
  end

  describe "search filter" do
    test "renders the filter panel", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/my/cards")

      assert has_element?(index_live, "#checklist-search-filter")
      assert has_element?(index_live, "#checklist-search-filter-date")
    end

    test "a date filter narrows the listed cards", %{conn: conn, user: user} do
      match = insert(:checklist, user: user, observ_date: ~D[2024-05-01])
      other = insert(:checklist, user: user, observ_date: ~D[2024-05-02])

      {:ok, index_live, _html} = live(conn, ~p"/my/cards")

      index_live
      |> form("#checklist-search-filter", filter: %{date: "2024-05-01"})
      |> render_submit()

      assert has_element?(index_live, "#checklist-#{match.id}")
      refute has_element?(index_live, "#checklist-#{other.id}")
    end

    test "the unresolved filter shows only unresolved cards", %{conn: conn, user: user} do
      unresolved = insert(:checklist, user: user, resolved: false)
      resolved = insert(:checklist, user: user, resolved: true)

      {:ok, index_live, _html} = live(conn, ~p"/my/cards")

      index_live
      |> form("#checklist-search-filter", filter: %{unresolved: "true"})
      |> render_submit()

      assert has_element?(index_live, "#checklist-#{unresolved.id}")
      refute has_element?(index_live, "#checklist-#{resolved.id}")
    end

    test "an observation-level filter shows only matching observations", %{
      conn: conn,
      user: user
    } do
      {taxon, _page} = Kjogvi.Factory.create_species_taxon_with_page()
      key = Ornitho.Schema.Taxon.key(taxon)

      checklist = insert(:checklist, user: user)
      heard = insert(:observation, checklist: checklist, taxon_key: key, voice: true)

      seen =
        insert(:observation,
          checklist: checklist,
          taxon_key: "ebird/eBird_2023/amecro",
          voice: false
        )

      {:ok, index_live, _html} = live(conn, ~p"/my/cards")

      index_live
      |> form("#checklist-search-filter", filter: %{voice: "heard_only"})
      |> render_submit()

      assert has_element?(index_live, "#checklist-#{checklist.id}-obs-#{heard.id}")
      refute has_element?(index_live, "#checklist-#{checklist.id}-obs-#{seen.id}")
    end

    test "submitting the filter patches the URL with the filter params", %{conn: conn, user: user} do
      insert(:checklist, user: user, observ_date: ~D[2024-05-01])

      {:ok, index_live, _html} = live(conn, ~p"/my/cards")

      index_live
      |> form("#checklist-search-filter", filter: %{date: "2024-05-01"})
      |> render_submit()

      assert_patch(index_live, ~p"/my/cards?date=2024-05-01")
    end

    test "a filtered URL renders the filtered view directly", %{conn: conn, user: user} do
      match = insert(:checklist, user: user, observ_date: ~D[2024-05-01])
      other = insert(:checklist, user: user, observ_date: ~D[2024-05-02])

      {:ok, index_live, _html} = live(conn, ~p"/my/cards?date=2024-05-01")

      assert has_element?(index_live, "#checklist-#{match.id}")
      refute has_element?(index_live, "#checklist-#{other.id}")
      assert has_element?(index_live, "#checklist-search-filter-date[value='2024-05-01']")
    end

    test "a taxon_key in the URL restores the autocomplete label", %{conn: conn} do
      {taxon, _page} = Kjogvi.Factory.create_species_taxon_with_page()
      key = Ornitho.Schema.Taxon.key(taxon)

      {:ok, index_live, _html} = live(conn, ~p"/my/cards?taxon_key=#{key}")

      assert has_element?(
               index_live,
               "#checklist-search-filter-taxon[value='#{taxon.name_en}']"
             )
    end

    test "a location_id in the URL narrows to that location", %{conn: conn, user: user} do
      location = insert(:location)
      match = insert(:checklist, user: user, location: location)
      other = insert(:checklist, user: user)

      {:ok, index_live, _html} = live(conn, ~p"/my/cards?location_id=#{location.id}")

      assert has_element?(index_live, "#checklist-#{match.id}")
      refute has_element?(index_live, "#checklist-#{other.id}")
    end

    test "reset patches back to the bare cards URL", %{conn: conn, user: user} do
      insert(:checklist, user: user, observ_date: ~D[2024-05-01])

      {:ok, index_live, _html} = live(conn, ~p"/my/cards?date=2024-05-01")

      index_live |> element("button", "Reset") |> render_click()

      assert_patch(index_live, ~p"/my/cards")
    end

    test "pagination links carry the active filter", %{conn: conn, user: user} do
      insert_list(21, :checklist, user: user, observ_date: ~D[2024-05-01])

      {:ok, _index_live, html} = live(conn, ~p"/my/cards?date=2024-05-01")

      assert html =~ "/cards/page/2?date=2024-05-01"
    end

    test "shows a no-match message and reset clears the filter", %{conn: conn, user: user} do
      checklist = insert(:checklist, user: user, observ_date: ~D[2024-05-01])

      {:ok, index_live, _html} = live(conn, ~p"/my/cards")

      html =
        index_live
        |> form("#checklist-search-filter", filter: %{date: "1999-01-01"})
        |> render_submit()

      assert html =~ "No cards match the current filter."
      refute has_element?(index_live, "#checklist-#{checklist.id}")

      index_live |> element("button", "Reset") |> render_click()

      assert has_element?(index_live, "#checklist-#{checklist.id}")
    end
  end
end
