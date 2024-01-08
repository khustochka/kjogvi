defmodule OrnithoWeb.Live.Taxa.TableTest do
  use OrnithoWeb.ConnCase
  use OrnithoWeb.OrnithoCase, async: true

  import Phoenix.LiveViewTest

  describe "Table" do
    test "expands and collapses the taxon", %{conn: conn} do
      book = insert(:book)
      insert(:taxon, book: book)

      {:ok, show_live, _html} = live(conn, "/taxonomy/#{book.slug}/#{book.version}")

      show_live |> element("span[phx-click]", "Expand") |> render_click()

      assert show_live |> has_element?("span", "Collapse")
      assert show_live |> has_element?("dt", "species_group")
      assert show_live |> has_element?("dd", "Cuckoos")

      show_live |> element("span[phx-click]", "Collapse") |> render_click()

      assert not (show_live |> has_element?("span", "Collapse"))
      assert not (show_live |> has_element?("dt", "species_group"))
      assert not (show_live |> has_element?("dd", "Cuckoos"))
    end

    test "shows parent species", %{conn: conn} do
      book = insert(:book)
      parent = insert(:taxon, book: book)
      insert(:taxon, book: book, category: "issf", parent_species: parent)

      {:ok, show_live, _html} = live(conn, "/taxonomy/#{book.slug}/#{book.version}")

      assert show_live |> has_element?("td:nth-child(4) a", parent.name_sci)
    end
  end
end
