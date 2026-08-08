defmodule OrnithoWeb.Live.Taxa.IndexTest do
  use OrnithoWeb.ConnCase, async: true
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

    test "the next link shows the following taxa", %{conn: conn} do
      book = insert(:book)

      for i <- 1..30 do
        insert(:taxon, book: book, sort_order: i, name_sci: "Taxon numerus#{i}")
      end

      {:ok, show_live, html} = live(conn, "/taxonomy/#{book.slug}/#{book.version}")

      assert html =~ "Taxon numerus1"
      refute html =~ "Taxon numerus30"

      html2 = show_live |> element("#taxa-pagination-bottom-next") |> render_click()

      assert html2 =~ "Taxon numerus30"
      refute html2 =~ "Taxon numerus1"
      refute has_element?(show_live, "#taxa-pagination-bottom-next")
    end

    test "the next link is a real href anchored to the table", %{conn: conn} do
      book = insert(:book)

      for i <- 1..30 do
        insert(:taxon, book: book, sort_order: i)
      end

      {:ok, show_live, _html} = live(conn, "/taxonomy/#{book.slug}/#{book.version}")

      href =
        show_live
        |> element("#taxa-pagination-bottom-next")
        |> render()
        |> then(&Regex.run(~r/href="([^"]+)"/, &1))
        |> Enum.at(1)

      assert href == "/taxonomy/#{book.slug}/#{book.version}/page/2#taxa-list"
    end

    test "pagination appears both above and below the table", %{conn: conn} do
      book = insert(:book)

      for i <- 1..30 do
        insert(:taxon, book: book, sort_order: i)
      end

      {:ok, show_live, _html} = live(conn, "/taxonomy/#{book.slug}/#{book.version}")

      assert has_element?(show_live, "#taxa-pagination-top-next")
      assert has_element?(show_live, "#taxa-pagination-bottom-next")
    end

    test "the second page offers a link back to the previous one", %{conn: conn} do
      book = insert(:book)

      for i <- 1..30 do
        insert(:taxon, book: book, sort_order: i, name_sci: "Taxon numerus#{i}")
      end

      {:ok, show_live, _html} = live(conn, "/taxonomy/#{book.slug}/#{book.version}/page/2")

      assert has_element?(show_live, "#taxa-pagination-top-prev")

      html = show_live |> element("#taxa-pagination-bottom-prev") |> render_click()

      assert html =~ "Taxon numerus1"
    end

    test "no previous link on the first page", %{conn: conn} do
      book = insert(:book)

      for i <- 1..30 do
        insert(:taxon, book: book, sort_order: i)
      end

      {:ok, show_live, _html} = live(conn, "/taxonomy/#{book.slug}/#{book.version}")

      refute has_element?(show_live, "#taxa-pagination-top-prev")
    end

    test "a junk page number falls back to the first page", %{conn: conn} do
      book = insert(:book)

      for i <- 1..30 do
        insert(:taxon, book: book, sort_order: i, name_sci: "Taxon numerus#{i}")
      end

      {:ok, _show_live, html} =
        live(conn, "/taxonomy/#{book.slug}/#{book.version}/page/not-a-number")

      assert html =~ "Taxon numerus1"
    end

    test "no pagination when the book fits on one page", %{conn: conn} do
      book = insert(:book)
      insert(:taxon, book: book, sort_order: 1)

      {:ok, show_live, _html} = live(conn, "/taxonomy/#{book.slug}/#{book.version}")

      refute has_element?(show_live, "#taxa-pagination-top")
      refute has_element?(show_live, "#taxa-pagination-bottom")
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
