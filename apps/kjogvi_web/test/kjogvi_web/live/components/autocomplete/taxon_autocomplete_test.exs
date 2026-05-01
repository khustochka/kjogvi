defmodule KjogviWeb.Live.Components.TaxonAutocompleteTest do
  use KjogviWeb.ConnCase

  import Phoenix.LiveViewTest

  alias KjogviWeb.Live.Components.TaxonAutocomplete

  defmodule TestLive do
    use Phoenix.LiveView

    def render(assigns) do
      ~H"""
      <TaxonAutocomplete.taxon_autocomplete
        id="tax"
        hidden_name="card[observations][0][taxon_key]"
        hidden_value=""
        current_value="House Sparrow"
        user={@user}
        label="Taxon"
        on_select_event="taxon_selected"
      />
      """
    end

    def mount(_params, _session, socket) do
      # default_book_signature is nil → search returns []. We only
      # need the wrapper to render — DB queries do not run unless the
      # user types into the field.
      {:ok, Phoenix.Component.assign(socket, :user, %{default_book_signature: nil})}
    end
  end

  @endpoint KjogviWeb.Endpoint

  test "renders label, search input, and hidden field", %{conn: conn} do
    {:ok, _lv, html} = live_isolated(conn, TestLive)

    assert html =~ "Taxon"
    assert html =~ "Search and select taxon..."
    assert html =~ "House Sparrow"
    assert html =~ ~s(name="card[observations][0][taxon_key]")
  end
end
