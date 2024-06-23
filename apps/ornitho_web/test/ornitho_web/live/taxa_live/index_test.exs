defmodule OrnithoWeb.Live.Taxa.IndexTest do
  use OrnithoWeb.ConnCase
  use OrnithoWeb.OrnithoCase, async: true

  import Phoenix.LiveViewTest

  defp extract_sci_names(html) do
    {:ok, doc} = Floki.parse_document(html)

    # Do not trim the strings, this checks that there are no dangling underlines
    Floki.find(doc, "strong a em.sci_name")
    |> Enum.map(&Floki.text/1)
  end

  describe "Index" do
    test "displays taxa", %{conn: conn} do
      book = insert(:book)
      taxon = insert(:taxon, book: book)
      insert(:taxon, book: book)
      insert(:taxon, book: book)

      {:ok, _show_live, html} = live(conn, "/taxonomy/#{book.slug}/#{book.version}")

      assert html =~ taxon.name_sci
    end

    test "spaces are trimmed from the beginning and end of the search term", %{conn: conn} do
      book = insert(:book)
      insert(:taxon, book: book, name_sci: "Acrocephalus palustris")
      taxon2 = insert(:taxon, book: book)

      {:ok, show_live, _html} = live(conn, "/taxonomy/#{book.slug}/#{book.version}")

      html2 =
        show_live
        |> form("#taxa-search")
        |> render_change(%{"search_term" => " acr"})

      names = extract_sci_names(html2)

      assert "Acrocephalus palustris" in names
      assert taxon2.name_sci not in names
    end

    test "when search term is less than 3 letters, shows the page", %{conn: conn} do
      book = insert(:book)
      insert(:taxon, book: book, name_sci: "Acrocephalus palustris")
      taxon2 = insert(:taxon, book: book)

      {:ok, show_live, _html} = live(conn, "/taxonomy/#{book.slug}/#{book.version}")

      html2 =
        show_live
        |> form("#taxa-search")
        |> render_change(%{"search_term" => "ac"})

      names = extract_sci_names(html2)

      assert "Acrocephalus palustris" in names
      assert taxon2.name_sci in names
    end

    test "when search term is 3 letters or more, shows the search results", %{conn: conn} do
      book = insert(:book)
      insert(:taxon, book: book, name_sci: "Acrocephalus palustris")
      insert(:taxon, book: book)

      {:ok, show_live, html} = live(conn, "/taxonomy/#{book.slug}/#{book.version}")

      assert html =~ "Acrocephalus palustris"
      assert html =~ "Cuculus canorus"

      html2 =
        show_live
        |> form("#taxa-search")
        |> render_change(%{"search_term" => "acr"})

      assert extract_sci_names(html2) == ["Acrocephalus palustris"]
    end

    test "when search term is cleared, shows the page", %{conn: conn} do
      book = insert(:book)
      insert(:taxon, book: book, name_sci: "Acrocephalus palustris")
      taxon2 = insert(:taxon, book: book)

      {:ok, show_live, _html} = live(conn, "/taxonomy/#{book.slug}/#{book.version}")

      html2 =
        show_live
        |> form("#taxa-search")
        |> render_change(%{"search_term" => "acr"})

      names = extract_sci_names(html2)

      assert "Acrocephalus palustris" in names
      assert taxon2.name_sci not in names

      html3 =
        show_live
        |> form("#taxa-search")
        |> render_change(%{"search_term" => ""})

      assert html3 =~ "Acrocephalus palustris"
      assert html3 =~ "Cuculus canorus"
    end
  end
end
