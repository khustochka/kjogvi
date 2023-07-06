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

  describe "GET /taxonomy/:book_slug" do
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
      Ops.Book.mark_book_imported(book)

      conn = get(conn, ~p"/taxonomy/#{book.slug}/#{book.version}")
      resp = html_response(conn, 200)
      assert resp =~ book.name
    end
  end
end
