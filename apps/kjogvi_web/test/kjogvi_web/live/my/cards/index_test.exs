defmodule KjogviWeb.Live.My.Cards.IndexTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.UsersFixtures

  setup %{conn: conn} do
    user = user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  test "renders with no cards", %{conn: conn} do
    {:ok, index_live, _html} = live(conn, ~p"/my/cards")

    assert index_live
           |> element("h1", "Cards")
           |> render()
  end

  test "renders a card as a panel with location", %{conn: conn, user: user} do
    card = insert(:card, user: user)

    {:ok, index_live, _html} = live(conn, ~p"/my/cards")

    assert has_element?(index_live, "#cards")
    assert has_element?(index_live, "#card-#{card.id}")
    assert render(index_live) =~ "Winnipeg"
  end

  test "panel links to show, edit and counts", %{conn: conn, user: user} do
    {taxon, _page} = Kjogvi.Factory.create_species_taxon_with_page()
    key = Ornitho.Schema.Taxon.key(taxon)

    card = insert(:card, user: user)
    insert(:observation, card: card, taxon_key: key)
    insert(:observation, card: card, taxon_key: "ebird/eBird_2023/amecro")

    {:ok, index_live, _html} = live(conn, ~p"/my/cards")

    panel = element(index_live, "#card-#{card.id}")
    assert has_element?(index_live, ~s{#card-#{card.id} a[href="/my/cards/#{card.id}"]})

    assert has_element?(
             index_live,
             ~s{#card-#{card.id} a[href="/my/cards/#{card.id}/edit"]},
             "Edit"
           )

    # 1 countable species, 2 distinct taxa, 2 observations.
    rendered = render(panel)
    assert rendered =~ "sp."
    assert rendered =~ "taxa"
    assert rendered =~ "obs"
  end

  test "panel does not list observations by default (card mode)", %{conn: conn, user: user} do
    {taxon, _page} = Kjogvi.Factory.create_species_taxon_with_page()
    key = Ornitho.Schema.Taxon.key(taxon)

    card = insert(:card, user: user)
    obs = insert(:observation, card: card, taxon_key: key)

    {:ok, index_live, _html} = live(conn, ~p"/my/cards")

    assert has_element?(index_live, "#card-#{card.id}")
    refute has_element?(index_live, "#card-#{card.id}-obs-#{obs.id}")
  end

  test "panel links to eBird checklist when ebird_id present", %{conn: conn, user: user} do
    card = insert(:card, user: user, ebird_id: "S100803884")

    {:ok, index_live, _html} = live(conn, ~p"/my/cards")

    assert has_element?(
             index_live,
             ~s{#card-#{card.id} a[href="https://ebird.org/checklist/S100803884"]}
           )
  end

  test "panel omits eBird link when ebird_id is absent", %{conn: conn, user: user} do
    card = insert(:card, user: user, ebird_id: nil)

    {:ok, index_live, _html} = live(conn, ~p"/my/cards")

    refute has_element?(index_live, ~s{#card-#{card.id} a[href^="https://ebird.org/checklist/"]})
  end

  test "deletes a card with no observations", %{conn: conn, user: user} do
    card = insert(:card, user: user)

    {:ok, index_live, _html} = live(conn, ~p"/my/cards")

    assert index_live
           |> element("#delete-card-#{card.id}")
           |> render_click()

    refute has_element?(index_live, "#card-#{card.id}")
    refute Kjogvi.Repo.get(Kjogvi.Birding.Card, card.id)
  end

  test "delete control is inert for a card with observations", %{conn: conn, user: user} do
    card = insert(:card, user: user)
    insert(:observation, card: card, taxon_key: "ebird/eBird_2023/amecro")

    {:ok, index_live, _html} = live(conn, ~p"/my/cards")

    # Rendered as a plain <span>, not a clickable button: no phx-click wiring.
    assert has_element?(index_live, "span#delete-card-#{card.id}")
    refute has_element?(index_live, "#delete-card-#{card.id}[phx-click]")
  end

  test "pagination with multiple cards", %{conn: conn, user: user} do
    location = insert(:location)
    insert_list(21, :card, location: location, user: user)

    {:ok, _index_live, html} = live(conn, ~p"/my/cards")

    assert html =~ "/cards/page/2"
  end

  describe "search filter" do
    test "renders the filter panel", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/my/cards")

      assert has_element?(index_live, "#card-search-filter")
      assert has_element?(index_live, "#card-search-filter-date")
    end

    test "a date filter narrows the listed cards", %{conn: conn, user: user} do
      match = insert(:card, user: user, observ_date: ~D[2024-05-01])
      other = insert(:card, user: user, observ_date: ~D[2024-05-02])

      {:ok, index_live, _html} = live(conn, ~p"/my/cards")

      index_live
      |> form("#card-search-filter", filter: %{date: "2024-05-01"})
      |> render_submit()

      assert has_element?(index_live, "#card-#{match.id}")
      refute has_element?(index_live, "#card-#{other.id}")
    end

    test "an observation-level filter shows only matching observations", %{
      conn: conn,
      user: user
    } do
      {taxon, _page} = Kjogvi.Factory.create_species_taxon_with_page()
      key = Ornitho.Schema.Taxon.key(taxon)

      card = insert(:card, user: user)
      heard = insert(:observation, card: card, taxon_key: key, voice: true)
      seen = insert(:observation, card: card, taxon_key: "ebird/eBird_2023/amecro", voice: false)

      {:ok, index_live, _html} = live(conn, ~p"/my/cards")

      index_live
      |> form("#card-search-filter", filter: %{voice: "heard_only"})
      |> render_submit()

      assert has_element?(index_live, "#card-#{card.id}-obs-#{heard.id}")
      refute has_element?(index_live, "#card-#{card.id}-obs-#{seen.id}")
    end

    test "submitting the filter patches the URL with the filter params", %{conn: conn, user: user} do
      insert(:card, user: user, observ_date: ~D[2024-05-01])

      {:ok, index_live, _html} = live(conn, ~p"/my/cards")

      index_live
      |> form("#card-search-filter", filter: %{date: "2024-05-01"})
      |> render_submit()

      assert_patch(index_live, ~p"/my/cards?date=2024-05-01")
    end

    test "a filtered URL renders the filtered view directly", %{conn: conn, user: user} do
      match = insert(:card, user: user, observ_date: ~D[2024-05-01])
      other = insert(:card, user: user, observ_date: ~D[2024-05-02])

      {:ok, index_live, _html} = live(conn, ~p"/my/cards?date=2024-05-01")

      assert has_element?(index_live, "#card-#{match.id}")
      refute has_element?(index_live, "#card-#{other.id}")
      assert has_element?(index_live, "#card-search-filter-date[value='2024-05-01']")
    end

    test "a taxon_key in the URL restores the autocomplete label", %{conn: conn} do
      {taxon, _page} = Kjogvi.Factory.create_species_taxon_with_page()
      key = Ornitho.Schema.Taxon.key(taxon)

      {:ok, index_live, _html} = live(conn, ~p"/my/cards?taxon_key=#{key}")

      assert has_element?(
               index_live,
               "#card-search-filter-taxon[value='#{taxon.name_en}']"
             )
    end

    test "a location_id in the URL narrows to that location", %{conn: conn, user: user} do
      location = insert(:location)
      match = insert(:card, user: user, location: location)
      other = insert(:card, user: user)

      {:ok, index_live, _html} = live(conn, ~p"/my/cards?location_id=#{location.id}")

      assert has_element?(index_live, "#card-#{match.id}")
      refute has_element?(index_live, "#card-#{other.id}")
    end

    test "reset patches back to the bare cards URL", %{conn: conn, user: user} do
      insert(:card, user: user, observ_date: ~D[2024-05-01])

      {:ok, index_live, _html} = live(conn, ~p"/my/cards?date=2024-05-01")

      index_live |> element("button", "Reset") |> render_click()

      assert_patch(index_live, ~p"/my/cards")
    end

    test "pagination links carry the active filter", %{conn: conn, user: user} do
      insert_list(21, :card, user: user, observ_date: ~D[2024-05-01])

      {:ok, _index_live, html} = live(conn, ~p"/my/cards?date=2024-05-01")

      assert html =~ "/cards/page/2?date=2024-05-01"
    end

    test "shows a no-match message and reset clears the filter", %{conn: conn, user: user} do
      card = insert(:card, user: user, observ_date: ~D[2024-05-01])

      {:ok, index_live, _html} = live(conn, ~p"/my/cards")

      html =
        index_live
        |> form("#card-search-filter", filter: %{date: "1999-01-01"})
        |> render_submit()

      assert html =~ "No cards match the current filter."
      refute has_element?(index_live, "#card-#{card.id}")

      index_live |> element("button", "Reset") |> render_click()

      assert has_element?(index_live, "#card-#{card.id}")
    end
  end
end
