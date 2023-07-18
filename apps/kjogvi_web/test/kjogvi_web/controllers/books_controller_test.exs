defmodule KjogviWeb.BooksControllerTest do
  use KjogviWeb.ConnCase, async: true
  use KjogviWeb.OrnithoCase

  alias Ornitho.Ops

  describe "GET /taxonomy" do
    test "No books", %{conn: conn} do
      conn = get(conn, ~p"/taxonomy")
      assert html_response(conn, 200) =~ "slug"
    end

    test "Book with no taxa", %{conn: conn} do
      book = insert(:book)
      conn = get(conn, ~p"/taxonomy")
      resp = html_response(conn, 200)
      assert resp =~ book.slug
      assert resp =~ book.version
      assert resp =~ book.name
    end

    test "Book with taxa", %{conn: conn} do
      book = insert(:book)
      insert(:taxon, book: book)
      insert(:taxon, book: book)
      Ops.Book.mark_book_imported(book)

      conn = get(conn, ~p"/taxonomy")
      resp = html_response(conn, 200)
      assert resp =~ book.slug
      assert resp =~ book.version
      assert resp =~ book.name
    end
  end

  # These tests do not have a controller, but still work; and it is still good
  # to test that they work without JavaScript.
  describe "GET /taxonomy/:slug/:version" do
    test "Book with no taxa", %{conn: conn} do
      book = insert(:book)
      conn = get(conn, ~p"/taxonomy/#{book.slug}/#{book.version}")
      resp = html_response(conn, 200)
      assert resp =~ book.name
    end

    test "Book with taxa", %{conn: conn} do
      book = insert(:book)
      insert(:taxon, book: book)
      insert(:taxon, book: book)

      conn = get(conn, ~p"/taxonomy/#{book.slug}/#{book.version}")
      resp = html_response(conn, 200)
      assert resp =~ book.name
    end
  end

  describe "GET /taxonomy/:slug/:version/page/:n" do
    test "shows n-th page", %{conn: conn} do
      book = insert(:book)

      taxa = insert_list(26, :taxon, book: book)

      conn = get(conn, ~p"/taxonomy/#{book.slug}/#{book.version}/page/2")
      resp = html_response(conn, 200)
      assert resp =~ List.last(taxa).name_sci
    end
  end
end
