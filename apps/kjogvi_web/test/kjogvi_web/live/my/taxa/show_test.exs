defmodule KjogviWeb.Live.My.Taxa.ShowTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures

  alias Ornitho.Schema.Taxon

  setup %{conn: conn} do
    user = user_fixture()
    book = Ornitho.Factory.insert(:book, name: "eBird/Clements Checklist v2026")
    species = Ornitho.Factory.insert(:taxon, book: book, name_en: "Mallard")

    subspecies =
      Ornitho.Factory.insert(:taxon,
        book: book,
        category: "issf",
        name_en: "Mallard (Northern)",
        parent_species: species
      )

    %{
      conn: login_user(conn, user),
      user: user,
      book: book,
      species: species,
      subspecies: subspecies
    }
  end

  defp taxon_path(book, taxon), do: ~p"/my/taxa/#{book.slug}/#{book.version}/#{taxon.code}"

  test "requires login", %{book: book, species: species} do
    assert {:error, {:redirect, %{to: "/account/login"}}} =
             live(build_conn(), taxon_path(book, species))
  end

  test "unknown taxon is not found", %{conn: conn, book: book} do
    assert_raise KjogviWeb.NotFoundError, fn ->
      live(conn, ~p"/my/taxa/#{book.slug}/#{book.version}/nosuchcode")
    end
  end

  test "unknown book is not found", %{conn: conn, species: species} do
    assert_raise KjogviWeb.NotFoundError, fn ->
      live(conn, ~p"/my/taxa/nosuchbook/v1/#{species.code}")
    end
  end

  test "shows the taxon and links to its species", %{
    conn: conn,
    book: book,
    species: species,
    subspecies: subspecies
  } do
    {:ok, lv, _html} = live(conn, taxon_path(book, subspecies))

    assert has_element?(lv, "h1", "Mallard (Northern)")
    assert has_element?(lv, "#taxon-details b", "eBird/Clements Checklist v2026")

    assert has_element?(
             lv,
             "#taxon-parent-species a[href='#{taxon_path(book, species)}']",
             "Mallard"
           )

    assert has_element?(lv, "#taxon-no-observations")
  end

  test "lists only the user's observations of exactly this taxon, marking the first record",
       %{conn: conn, user: user, book: book, species: species, subspecies: subspecies} do
    older = insert(:checklist, user: user, observ_date: ~D[2020-01-01])
    newer = insert(:checklist, user: user, observ_date: ~D[2021-01-01])
    first = insert(:observation, checklist: older, taxon_key: Taxon.key(species))
    later = insert(:observation, checklist: newer, taxon_key: Taxon.key(species), voice: true)
    child = insert(:observation, checklist: newer, taxon_key: Taxon.key(subspecies))
    others = insert(:observation, checklist: insert(:checklist), taxon_key: Taxon.key(species))

    {:ok, lv, _html} = live(conn, taxon_path(book, species))

    assert has_element?(lv, "#observation-#{first.id}", "First record")
    assert has_element?(lv, "#observation-#{first.id} a[href='/my/checklists/#{older.id}']")
    assert has_element?(lv, "#observation-#{later.id}", "Heard only")
    refute has_element?(lv, "#observation-#{later.id}", "First record")
    refute has_element?(lv, "#observation-#{child.id}")
    refute has_element?(lv, "#observation-#{others.id}")
  end

  test "an uncounted observation is not the first record", %{
    conn: conn,
    user: user,
    book: book,
    species: species
  } do
    uncounted =
      insert(:observation,
        checklist: insert(:checklist, user: user, observ_date: ~D[2019-01-01]),
        taxon_key: Taxon.key(species),
        unreported: true
      )

    counted =
      insert(:observation,
        checklist: insert(:checklist, user: user, observ_date: ~D[2020-01-01]),
        taxon_key: Taxon.key(species)
      )

    {:ok, lv, _html} = live(conn, taxon_path(book, species))

    assert has_element?(lv, "#observation-#{uncounted.id}", "Not counted")
    refute has_element?(lv, "#observation-#{uncounted.id}", "First record")
    assert has_element?(lv, "#observation-#{counted.id}", "First record")
  end

  test "paginates observations, keeping the first record mark on its page",
       %{conn: conn, user: user, book: book, species: species} do
    first =
      insert(:observation,
        checklist: insert(:checklist, user: user, observ_date: ~D[2000-01-01]),
        taxon_key: Taxon.key(species)
      )

    checklist = insert(:checklist, user: user, observ_date: ~D[2020-01-01])

    for _ <- 1..50,
        do: insert(:observation, checklist: checklist, taxon_key: Taxon.key(species))

    {:ok, lv, _html} = live(conn, taxon_path(book, species))

    assert has_element?(lv, "h2", "(51)")
    refute has_element?(lv, "#observation-#{first.id}")

    assert has_element?(
             lv,
             "#taxon-observations-pagination a[href^='#{taxon_path(book, species)}/page/2']"
           )

    {:ok, lv, _html} = live(conn, "#{taxon_path(book, species)}/page/2")

    assert has_element?(lv, "#observation-#{first.id}", "First record")
  end
end
