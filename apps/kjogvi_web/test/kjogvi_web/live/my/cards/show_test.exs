defmodule KjogviWeb.Live.My.Cards.ShowTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures

  setup %{conn: conn} do
    user = user_fixture()
    %{conn: login_user(conn, user), user: user}
  end

  test "renders breadcrumbs with link to cards index", %{conn: conn, user: user} do
    card = insert(:card, user: user)

    {:ok, show_live, _html} = live(conn, ~p"/my/cards/#{card.id}")

    assert has_element?(show_live, "#card-breadcrumbs")
    assert has_element?(show_live, "#card-breadcrumbs a", "Cards")
  end

  test "renders with no observations", %{conn: conn, user: user} do
    card = insert(:card, user: user)

    {:ok, _show_live, html} = live(conn, ~p"/my/cards/#{card.id}")

    assert html =~ "Card ##{card.id}"
    assert html =~ "This card has no observations."
  end

  test "shows an unresolved marker for unresolved cards", %{conn: conn, user: user} do
    card = insert(:card, user: user, resolved: false)

    {:ok, show_live, _html} = live(conn, ~p"/my/cards/#{card.id}")

    assert has_element?(show_live, "#card-unresolved")
  end

  test "has no unresolved marker for resolved cards", %{conn: conn, user: user} do
    card = insert(:card, user: user, resolved: true)

    {:ok, show_live, _html} = live(conn, ~p"/my/cards/#{card.id}")

    refute has_element?(show_live, "#card-unresolved")
  end

  test "renders an edit link", %{conn: conn, user: user} do
    card = insert(:card, user: user)

    {:ok, show_live, _html} = live(conn, ~p"/my/cards/#{card.id}")

    assert has_element?(show_live, ~s{a[href="/my/cards/#{card.id}/edit"]})
  end

  test "renders an eBird link when ebird_id is present", %{conn: conn, user: user} do
    card = insert(:card, user: user, ebird_id: "S100803884")

    {:ok, show_live, _html} = live(conn, ~p"/my/cards/#{card.id}")

    assert has_element?(
             show_live,
             ~s{a[href="https://ebird.org/checklist/S100803884"]}
           )
  end

  test "renders eBird details panel when ebird_id is present", %{conn: conn, user: user} do
    card = insert(:card, user: user, ebird_id: "S100803884")

    {:ok, show_live, _html} = live(conn, ~p"/my/cards/#{card.id}")

    assert has_element?(show_live, "#card-ebird-details", "S100803884")

    assert has_element?(
             show_live,
             ~s{#card-ebird-details a[href="https://ebird.org/checklist/S100803884"]}
           )
  end

  test "does not render eBird details panel when ebird_id is absent", %{conn: conn, user: user} do
    card = insert(:card, user: user, ebird_id: nil)

    {:ok, show_live, _html} = live(conn, ~p"/my/cards/#{card.id}")

    refute has_element?(show_live, "#card-ebird-details")
  end

  test "eBird panel shows Complete badge when ebird_complete is true", %{conn: conn, user: user} do
    card = insert(:card, user: user, ebird_id: "S1", ebird_complete: true)

    {:ok, show_live, _html} = live(conn, ~p"/my/cards/#{card.id}")

    assert has_element?(show_live, "#card-ebird-details", "Complete")
    refute has_element?(show_live, "#card-ebird-details", "Incomplete")
  end

  test "eBird panel shows Incomplete badge when ebird_complete is false", %{
    conn: conn,
    user: user
  } do
    card = insert(:card, user: user, ebird_id: "S1", ebird_complete: false)

    {:ok, show_live, _html} = live(conn, ~p"/my/cards/#{card.id}")

    assert has_element?(show_live, "#card-ebird-details", "Incomplete")
  end

  test "eBird panel shows no badge when ebird_complete is nil", %{conn: conn, user: user} do
    card = insert(:card, user: user, ebird_id: "S1", ebird_complete: nil)

    {:ok, show_live, _html} = live(conn, ~p"/my/cards/#{card.id}")

    refute has_element?(show_live, "#card-ebird-details", "Complete")
    refute has_element?(show_live, "#card-ebird-details", "Incomplete")
  end

  test "shows completeness badge in details panel when ebird_id absent but complete set", %{
    conn: conn,
    user: user
  } do
    card = insert(:card, user: user, ebird_id: nil, ebird_complete: false)

    {:ok, show_live, html} = live(conn, ~p"/my/cards/#{card.id}")

    # No separate eBird panel section, but the badge appears in the page body.
    refute has_element?(show_live, "#card-ebird-details")
    assert html =~ "Incomplete"
  end

  test "no completeness badge when both ebird_id and ebird_complete are absent", %{
    conn: conn,
    user: user
  } do
    card = insert(:card, user: user, ebird_id: nil, ebird_complete: nil)

    {:ok, show_live, html} = live(conn, ~p"/my/cards/#{card.id}")

    refute has_element?(show_live, "#card-ebird-details")
    refute html =~ "Incomplete"
    refute html =~ "Complete"
  end

  test "renders with observations present", %{conn: conn, user: user} do
    card = insert(:card, user: user)
    taxon = Ornitho.Factory.insert(:taxon, category: "spuh")
    insert(:observation, card: card, taxon_key: Ornitho.Schema.Taxon.key(taxon))

    {:ok, show_live, html} = live(conn, ~p"/my/cards/#{card.id}")

    assert html =~ "Card ##{card.id}"
    assert has_element?(show_live, "#observation")
  end

  test "deletes a card with no observations and navigates to index", %{conn: conn, user: user} do
    card = insert(:card, user: user)

    {:ok, show_live, _html} = live(conn, ~p"/my/cards/#{card.id}")

    assert {:error, {:live_redirect, %{to: "/my/cards"}}} =
             show_live
             |> element("#delete-card")
             |> render_click()

    refute Kjogvi.Repo.get(Kjogvi.Birding.Card, card.id)
  end

  test "delete control is inert when card has observations", %{conn: conn, user: user} do
    card = insert(:card, user: user)
    taxon = Ornitho.Factory.insert(:taxon, category: "spuh")
    insert(:observation, card: card, taxon_key: Ornitho.Schema.Taxon.key(taxon))

    {:ok, show_live, _html} = live(conn, ~p"/my/cards/#{card.id}")

    # Rendered as a plain <span>, not a clickable button: no phx-click wiring.
    assert has_element?(show_live, "span#delete-card")
    refute has_element?(show_live, "#delete-card[phx-click]")
  end

  test "shows an import source note when import_source is present", %{conn: conn, user: user} do
    card = insert(:card, user: user, import_source: :ebird)

    {:ok, show_live, _html} = live(conn, ~p"/my/cards/#{card.id}")

    assert has_element?(show_live, "#card-import-source", "Imported from: eBird")
  end

  test "shows no import source note when import_source is nil", %{conn: conn, user: user} do
    card = insert(:card, user: user, import_source: nil)

    {:ok, show_live, _html} = live(conn, ~p"/my/cards/#{card.id}")

    refute has_element?(show_live, "#card-import-source")
  end

  test "does not render for wrong user", %{conn: conn} do
    card = insert(:card, user: user_fixture())
    taxon = Ornitho.Factory.insert(:taxon, category: "spuh")
    insert(:observation, card: card, taxon_key: Ornitho.Schema.Taxon.key(taxon))

    assert_raise Ecto.NoResultsError, fn ->
      live(conn, ~p"/my/cards/#{card.id}")
    end
  end

  test "renders with unknown taxon", %{conn: conn, user: user} do
    card = insert(:card, user: user)
    insert(:observation, card: card, taxon_key: "/ioc/v1/pasdom")

    {:ok, _show_live, html} = live(conn, ~p"/my/cards/#{card.id}")

    assert html =~ "Card ##{card.id}"
    assert html =~ "Undefined taxon!"
  end
end
