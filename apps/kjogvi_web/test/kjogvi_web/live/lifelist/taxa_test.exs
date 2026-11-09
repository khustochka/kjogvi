defmodule KjogviWeb.Live.Lifelist.TaxaTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures

  alias Ornitho.Schema.Taxon

  setup %{conn: conn} do
    user = user_fixture()
    %{conn: login_user(conn, user), user: user}
  end

  test "requires login" do
    assert {:error, {:redirect, %{to: "/account/login"}}} =
             live(build_conn(), ~p"/my/taxa/lifelist")
  end

  test "redirects bare /my/taxa to the lifelist", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/my/taxa/lifelist"}}} = live(conn, ~p"/my/taxa")
  end

  test "without a default taxonomy, points to preferences", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/my/taxa/lifelist")

    assert has_element?(
             lv,
             "#taxa-no-default-book a[href='/my/settings/preferences#default-taxonomy']"
           )

    refute has_element?(lv, "#lifelist-table")
  end

  describe "with a default taxonomy" do
    setup %{user: user} do
      book = Ornitho.Factory.insert(:book, name: "eBird/Clements Checklist v2026")

      {:ok, _user} =
        Kjogvi.Accounts.set_default_book_signature(user, "#{book.slug}/#{book.version}")

      species = Ornitho.Factory.insert(:taxon, book: book, name_en: "Mallard")
      spuh = Ornitho.Factory.insert(:taxon, book: book, category: "spuh", name_en: "duck sp.")
      other_book_taxon = Ornitho.Factory.insert(:taxon, name_en: "Elsewhere Duck")

      older = insert(:checklist, user: user, observ_date: ~D[2022-05-01])
      newer = insert(:checklist, user: user, observ_date: ~D[2023-05-01])
      insert(:observation, checklist: older, taxon_key: Taxon.key(species))
      insert(:observation, checklist: newer, taxon_key: Taxon.key(spuh))
      insert(:observation, checklist: newer, taxon_key: Taxon.key(other_book_taxon))

      %{book: book, species: species, spuh: spuh, newer: newer}
    end

    test "lists the book's taxa, spuhs included, linking to personal taxon pages", %{
      conn: conn,
      book: book,
      species: species,
      spuh: spuh,
      newer: newer
    } do
      {:ok, lv, _html} = live(conn, ~p"/my/taxa/lifelist")

      assert has_element?(lv, "h1", "Taxa Lifelist")
      assert has_element?(lv, "#lifelist-book b", "eBird/Clements Checklist v2026")

      assert has_element?(
               lv,
               "#lifer-2 a[href='/my/taxa/#{book.slug}/#{book.version}/#{spuh.code}']",
               "duck sp."
             )

      assert has_element?(lv, "#lifer-2 a[href='/my/checklists/#{newer.id}']")

      assert has_element?(
               lv,
               "#lifer-1 a[href='/my/taxa/#{book.slug}/#{book.version}/#{species.code}']",
               "Mallard"
             )

      refute has_element?(lv, "#lifelist-table", "Elsewhere Duck")
    end

    test "shows taxa and species counts; the species count switches to Species only", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, ~p"/my/taxa/lifelist")

      assert has_element?(lv, "#lifelist-total", "2")
      assert has_element?(lv, "#lifelist-total", "taxa recorded")
      assert has_element?(lv, "#lifelist-species-total", "1")
      assert has_element?(lv, "#lifelist-species-total", "species recorded")

      lv |> element("#lifelist-species-total") |> render_click()
      assert_patch(lv, ~p"/my/taxa/lifelist?species_only=true")

      refute has_element?(lv, "#lifelist-species-total")
      assert has_element?(lv, "#lifelist-total", "species recorded")
    end

    test "uncountable taxa are not bold", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/my/taxa/lifelist")

      assert has_element?(lv, "#lifer-1 a.font-semibold", "Mallard")
      assert has_element?(lv, "#lifer-2 a", "duck sp.")
      refute has_element?(lv, "#lifer-2 a.font-semibold")
    end

    test "Species only toggle drops taxa without a species", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/my/taxa/lifelist")

      lv |> element("#lifelist-species-only a[role=switch]") |> render_click()
      assert_patch(lv, ~p"/my/taxa/lifelist?species_only=true")

      assert has_element?(lv, "#lifer-1", "Mallard")
      refute has_element?(lv, "#lifer-2")
      refute has_element?(lv, "ul[aria-label='Active filters']")
    end

    test "filter links stay in the taxa URL space", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/my/taxa/lifelist")

      assert has_element?(lv, "#lifelist-year-selector a[href='/my/taxa/lifelist/2023']")
      assert has_element?(lv, "ul[aria-label=Sort] a[href='/my/taxa/lifelist?sort=taxonomy']")
    end

    test "year and location URL reaches the lifelist, not a taxon page", %{conn: conn} do
      country = insert(:country, slug: "ukraine", name_en: "Ukraine")

      insert(:observation,
        checklist: insert(:checklist, observ_date: ~D[2022-06-01], location: country),
        taxon_key: "/nonexistent/v1/none"
      )

      {:ok, lv, _html} = live(conn, ~p"/my/taxa/lifelist/2022/ukraine")

      assert has_element?(lv, "#lifelist-table")
    end

    test "has no motorless or heard-only filters", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/my/taxa/lifelist?motorless=true&exclude_heard_only=true")

      refute has_element?(lv, "a[role=switch]", "Motorless only")
      refute has_element?(lv, "a[role=switch]", "Exclude heard only")
      refute has_element?(lv, "a[role=switch]", "Heard only excluded")
      refute has_element?(lv, "#heard-only-list")
      assert has_element?(lv, "#lifelist-table", "duck sp.")
    end

    test "year filter narrows the list", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/my/taxa/lifelist/2022")

      assert has_element?(lv, "#lifelist-table", "Mallard")
      refute has_element?(lv, "#lifelist-table", "duck sp.")
    end
  end
end
