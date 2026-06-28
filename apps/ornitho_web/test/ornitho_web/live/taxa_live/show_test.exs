defmodule OrnithoWeb.Live.Taxa.ShowTest do
  use OrnithoWeb.ConnCase, async: true
  use OrnithoWeb.OrnithoCase, async: true

  import Phoenix.LiveViewTest

  describe "Show" do
    test "displays taxon", %{conn: conn} do
      taxon = insert(:taxon)
      book = taxon.book

      {:ok, _show_live, html} = live(conn, "/taxonomy/#{book.slug}/#{book.version}/#{taxon.code}")

      assert html =~ book.slug
      assert html =~ book.version
      assert html =~ book.name
      assert html =~ taxon.name_sci
      assert html =~ taxon.name_en
    end

    test "displays each code type present in extras", %{conn: conn} do
      taxon =
        insert(:taxon,
          extras: %{
            "com_name_codes" => ["COOS"],
            "sci_name_codes" => ["STCA"],
            "banding_codes" => ["BAND"]
          }
        )

      book = taxon.book

      {:ok, show_live, _html} =
        live(conn, "/taxonomy/#{book.slug}/#{book.version}/#{taxon.code}")

      assert show_live |> element("#taxon-com_name_codes") |> render() =~ "COOS"
      assert show_live |> element("#taxon-sci_name_codes") |> render() =~ "STCA"
      assert show_live |> element("#taxon-banding_codes") |> render() =~ "BAND"
    end

    test "omits a code type that is absent or empty", %{conn: conn} do
      taxon = insert(:taxon, extras: %{"sci_name_codes" => ["STCA"], "banding_codes" => []})
      book = taxon.book

      {:ok, show_live, _html} =
        live(conn, "/taxonomy/#{book.slug}/#{book.version}/#{taxon.code}")

      assert has_element?(show_live, "#taxon-sci_name_codes")
      refute has_element?(show_live, "#taxon-com_name_codes")
      refute has_element?(show_live, "#taxon-banding_codes")
    end

    test "displays taxon with child taxa", %{conn: conn} do
      taxon = insert(:taxon)
      book = taxon.book
      child_taxon = insert(:taxon, book: book, parent_species: taxon)

      {:ok, _show_live, html} = live(conn, "/taxonomy/#{book.slug}/#{book.version}/#{taxon.code}")

      assert html =~ child_taxon.name_sci
      assert html =~ child_taxon.name_en
    end

    test "taxon does not exist", %{conn: conn} do
      book = insert(:book)

      assert_raise Ecto.NoResultsError, fn ->
        get(conn, "/taxonomy/#{book.slug}/#{book.version}/taxon")
      end
    end
  end
end
