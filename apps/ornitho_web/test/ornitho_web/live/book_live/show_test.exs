defmodule OrnithoWeb.Live.Book.ShowTest do
  use OrnithoWeb.ConnCase, async: true
  use OrnithoWeb.OrnithoCase, async: true

  import Phoenix.LiveViewTest

  describe "Show" do
    test "displays book", %{conn: conn} do
      book = insert(:book)

      {:ok, _show_live, html} = live(conn, "/taxonomy/#{book.slug}/#{book.version}")

      assert html =~ book.name
    end

    test "displays taxa", %{conn: conn} do
      book = insert(:book)
      taxon = insert(:taxon, book: book)
      insert(:taxon, book: book, category: "species")
      insert(:taxon, book: book, category: "issf")
      insert(:taxon, book: book, category: "spuh")
      insert(:taxon, book: book, category: "hybrid")
      insert(:taxon, book: book, category: "random")

      {:ok, _show_live, html} = live(conn, "/taxonomy/#{book.slug}/#{book.version}")

      assert html =~ taxon.name_sci
    end

    test "displays taxa on next pages", %{conn: conn} do
      book = insert(:book)

      taxa = insert_list(26, :taxon, book: book)

      {:ok, _show_live, html} = live(conn, "/taxonomy/#{book.slug}/#{book.version}/page/2")

      assert html =~ List.last(taxa).name_sci
    end

    test "navigates to next page", %{conn: conn} do
      book = insert(:book)

      taxa = insert_list(26, :taxon, book: book)

      {:ok, show_live, _html} = live(conn, "/taxonomy/#{book.slug}/#{book.version}")

      html = show_live |> element("ul.pagination a", "2") |> render_click()

      assert html =~ List.last(taxa).name_sci

      assert_patch(show_live, "/taxonomy/#{book.slug}/#{book.version}/page/2")
    end
  end

  # These pages render without JavaScript, so it is still good to test that they
  # work as plain HTTP responses too.
  describe "GET /taxonomy/:slug/:version" do
    test "Book with no taxa", %{conn: conn} do
      book = insert(:book)
      conn = get(conn, "/taxonomy/#{book.slug}/#{book.version}")
      resp = html_response(conn, 200)
      assert resp =~ book.name
    end

    test "Book with taxa", %{conn: conn} do
      book = insert(:book)
      insert(:taxon, book: book)
      insert(:taxon, book: book)

      conn = get(conn, "/taxonomy/#{book.slug}/#{book.version}")
      resp = html_response(conn, 200)
      assert resp =~ book.name
    end

    test "Book does not exist", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn ->
        get(conn, "/taxonomy/nonexistent/v1")
      end
    end
  end

  describe "GET /taxonomy/:slug/:version/page/:n" do
    test "shows n-th page", %{conn: conn} do
      book = insert(:book)

      taxa = insert_list(26, :taxon, book: book)

      conn = get(conn, "/taxonomy/#{book.slug}/#{book.version}/page/2")
      resp = html_response(conn, 200)
      assert resp =~ List.last(taxa).name_sci
    end
  end
end
