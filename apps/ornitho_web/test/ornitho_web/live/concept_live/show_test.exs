defmodule OrnithoWeb.Live.Concept.ShowTest do
  use OrnithoWeb.ConnCase, async: true
  use OrnithoWeb.OrnithoCase, async: true

  import Phoenix.LiveViewTest

  describe "Show" do
    test "lists taxa sharing the concept id", %{conn: conn} do
      concept_id = "avibase-2247CB05"
      taxon = insert(:taxon, taxon_concept_id: concept_id)

      {:ok, show_live, _html} = live(conn, "/taxonomy/concepts/#{concept_id}")

      assert has_element?(show_live, "a", taxon.name_sci)
    end
  end
end
