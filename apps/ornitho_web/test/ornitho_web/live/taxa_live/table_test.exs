defmodule OrnithoWeb.Live.Taxa.TableTest do
  use OrnithoWeb.ConnCase, async: true
  use OrnithoWeb.OrnithoCase, async: true

  import Phoenix.LiveViewTest

  describe "Table" do
    test "shows parent species", %{conn: conn} do
      book = insert(:book)
      parent = insert(:taxon, book: book)
      insert(:taxon, book: book, category: "issf", parent_species: parent)

      {:ok, show_live, _html} = live(conn, "/taxonomy/#{book.slug}/#{book.version}")

      assert show_live |> has_element?("td:nth-child(4) a", parent.name_sci)
    end
  end
end
