defmodule KjogviWeb.BooksControllerTest do
  use KjogviWeb.ConnCase, async: true
  use KjogviWeb.OrnithoCase

  describe "No books" do
    test "GET /taxonomy", %{conn: conn} do
      conn = get(conn, ~p"/taxonomy")
      assert html_response(conn, 200) =~ "slug"
    end
  end

  describe "Book with no taxa imported" do
    test "GET /taxonomy", %{conn: conn} do
      book = insert(:book)
      conn = get(conn, ~p"/taxonomy")
      resp = html_response(conn, 200)
      assert resp =~ book.slug
      assert resp =~ book.version
      assert resp =~ book.name
    end
  end

  describe "Book with taxa imported" do
    test "GET /taxonomy", %{conn: conn} do
      book = insert(:book)
      insert(:taxon, book: book)
      insert(:taxon, book: book)
      Ornitho.mark_book_imported(book)

      conn = get(conn, ~p"/taxonomy")
      resp = html_response(conn, 200)
      assert resp =~ book.slug
      assert resp =~ book.version
      assert resp =~ book.name
    end
  end
end
