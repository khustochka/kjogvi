defmodule KjogviWeb.TaxaLive.ShowTest do
  use KjogviWeb.ConnCase
  use KjogviWeb.OrnithoCase

  import Phoenix.LiveViewTest

  describe "Show" do
    test "displays taxon", %{conn: conn} do
      taxon = insert(:taxon)
      book = taxon.book

      {:ok, _show_live, html} = live(conn, ~p"/taxonomy/#{book.slug}/#{book.version}/#{taxon.code}")

      assert html =~ book.slug
      assert html =~ book.version
      assert html =~ book.name
      assert html =~ taxon.name_sci
      assert html =~ taxon.name_en
    end
  end
end
