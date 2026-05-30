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
end
