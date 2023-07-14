defmodule KjogviWeb.TaxaLive.TableTest do
  use KjogviWeb.ConnCase
  use KjogviWeb.OrnithoCase

  import Phoenix.LiveViewTest

  describe "Table" do
    test "displays taxa", %{conn: conn} do
      book = insert(:book)
      taxon = insert(:taxon, book: book)
      insert(:taxon, book: book)
      insert(:taxon, book: book)

      {:ok, _show_live, html} = live(conn, ~p"/taxonomy/#{book.slug}/#{book.version}")

      assert html =~ taxon.name_sci
    end

    test "spaces are trimmed from the beginning and end of the search term", %{conn: conn} do
      book = insert(:book)
      insert(:taxon, book: book, name_sci: "Acrocephalus palustris")
      insert(:taxon, book: book)

      {:ok, show_live, _html} = live(conn, ~p"/taxonomy/#{book.slug}/#{book.version}")

      html2 =
        show_live
        |> element("form input#taxa-search")
        |> render_change(%{"_target" => ["search_term"], "search_term" => " acr"})

      assert html2 =~ "Acrocephalus palustris"
      assert not(html2 =~ "Cuculus canorus")
    end

    test "when search term is less than 3 letters, shows the page", %{conn: conn} do
      book = insert(:book)
      insert(:taxon, book: book, name_sci: "Acrocephalus palustris")
      insert(:taxon, book: book)

      {:ok, show_live, _html} = live(conn, ~p"/taxonomy/#{book.slug}/#{book.version}")

      html2 =
        show_live
        |> element("form input#taxa-search")
        |> render_change(%{"_target" => ["search_term"], "search_term" => "ac"})

      assert html2 =~ "Acrocephalus palustris"
      assert html2 =~ "Cuculus canorus"
    end

    test "when search term is 3 letters or more, shows the search results", %{conn: conn} do
      book = insert(:book)
      insert(:taxon, book: book, name_sci: "Acrocephalus palustris")
      insert(:taxon, book: book)

      {:ok, show_live, html} = live(conn, ~p"/taxonomy/#{book.slug}/#{book.version}")

      assert html =~ "Acrocephalus palustris"
      assert html =~ "Cuculus canorus"

      html2 =
        show_live
        |> element("form input#taxa-search")
        |> render_change(%{"_target" => ["search_term"], "search_term" => "acr"})

      assert html2 =~ "Acrocephalus palustris"
      assert not(html2 =~ "Cuculus canorus")
    end

    test "when search term is cleared, shows the page", %{conn: conn} do
      book = insert(:book)
      insert(:taxon, book: book, name_sci: "Acrocephalus palustris")
      insert(:taxon, book: book)

      {:ok, show_live, _html} = live(conn, ~p"/taxonomy/#{book.slug}/#{book.version}")

      html2 =
        show_live
        |> element("form input#taxa-search")
        |> render_change(%{"_target" => ["search_term"], "search_term" => "acr"})

      assert html2 =~ "Acrocephalus palustris"
      assert not(html2 =~ "Cuculus canorus")

      html3 =
        show_live
        |> element("form input#taxa-search")
        |> render_change(%{"_target" => ["search_term"], "search_term" => ""})

      assert html3 =~ "Acrocephalus palustris"
      assert html3 =~ "Cuculus canorus"
    end
  end
end
