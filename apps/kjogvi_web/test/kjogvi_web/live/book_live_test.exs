defmodule KjogviWeb.BookLiveTest do
  use KjogviWeb.ConnCase
  use KjogviWeb.OrnithoCase

  import Phoenix.LiveViewTest

  describe "Show" do
    test "displays book", %{conn: conn} do
      book = insert(:book)

      {:ok, _show_live, html} = live(conn, ~p"/taxonomy/#{book.slug}/#{book.version}")

      assert html =~ book.slug
      assert html =~ book.version
      assert html =~ book.name
    end

    test "displays taxa", %{conn: conn} do
      book = insert(:book)
      taxon = insert(:taxon, book: book)
      insert(:taxon, book: book)
      insert(:taxon, book: book)

      {:ok, _show_live, html} = live(conn, ~p"/taxonomy/#{book.slug}/#{book.version}")

      assert html =~ taxon.name_sci
    end

    test "displays taxa on next pages", %{conn: conn} do
      book = insert(:book)

      taxa =
        1..26
        |> Enum.to_list()
        |> Enum.map(fn _ -> insert(:taxon, book: book) end)

      {:ok, _show_live, html} = live(conn, ~p"/taxonomy/#{book.slug}/#{book.version}/page/2")

      assert html =~ List.last(taxa).name_sci
    end

    test "navigates to next page", %{conn: conn} do
      book = insert(:book)

      taxa =
        1..26
        |> Enum.to_list()
        |> Enum.map(fn _ -> insert(:taxon, book: book) end)

      {:ok, show_live, _html} = live(conn, ~p"/taxonomy/#{book.slug}/#{book.version}")

      html = show_live |> element("a", "Page 2") |> render_click()

      assert html =~ List.last(taxa).name_sci

      assert_patch(show_live, ~p"/taxonomy/#{book.slug}/#{book.version}/page/2")
    end
  end
end
