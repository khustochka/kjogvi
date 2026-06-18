defmodule OrnithoWeb.Live.Book.IndexTest do
  use OrnithoWeb.ConnCase, async: true
  use OrnithoWeb.OrnithoCase, async: true

  import Phoenix.LiveViewTest

  describe "Index" do
    test "shows an empty-state message when no books are imported", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, "/taxonomy")
      assert has_element?(index_live, "#taxonomy-index-books-empty")
      refute has_element?(index_live, "#taxonomy-index-books")
    end

    test "Book with no taxa", %{conn: conn} do
      book = insert(:book)
      # Need to seed the atom
      # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
      _ = String.to_atom(book.importer)

      {:ok, _index_live, html} = live(conn, "/taxonomy")

      assert html =~ book.slug
      assert html =~ book.version
      assert html =~ book.name
    end

    test "links to a book", %{conn: conn} do
      book = insert(:book)
      # Need to seed the atom
      # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
      _ = String.to_atom(book.importer)

      {:ok, index_live, _html} = live(conn, "/taxonomy")

      assert index_live
             |> element("#taxonomy-index-books a", book.name)
             |> render_click()

      assert_redirect(index_live, "/taxonomy/#{book.slug}/#{book.version}")
    end
  end

  # These pages render without JavaScript, so it is still good to test that they
  # work as plain HTTP responses too.
  describe "GET /taxonomy" do
    test "renders without a connected socket", %{conn: conn} do
      book = insert(:book)
      # Need to seed the atom
      # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
      _ = String.to_atom(book.importer)

      conn = get(conn, "/taxonomy")
      resp = html_response(conn, 200)
      assert resp =~ book.slug
      assert resp =~ book.name
    end
  end
end
