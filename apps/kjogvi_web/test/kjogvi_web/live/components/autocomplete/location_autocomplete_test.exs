defmodule KjogviWeb.Live.Components.LocationAutocompleteTest do
  use KjogviWeb.ConnCase

  import Phoenix.LiveViewTest

  alias KjogviWeb.Live.Components.LocationAutocomplete

  defmodule TestLive do
    use Phoenix.LiveView

    def render(assigns) do
      ~H"""
      <LocationAutocomplete.location_autocomplete
        id="loc"
        hidden_name="card[location_id]"
        hidden_value=""
        current_value="Currently selected location"
        label="Location"
        placeholder="Pick a location"
        on_select_event="location_selected"
      />
      """
    end

    def mount(_params, _session, socket), do: {:ok, socket}
  end

  @endpoint KjogviWeb.Endpoint

  test "renders label, search input, and hidden field", %{conn: conn} do
    {:ok, _lv, html} = live_isolated(conn, TestLive)

    assert html =~ "Location"
    assert html =~ "Pick a location"
    assert html =~ "Currently selected location"
    assert html =~ ~s(name="card[location_id]")
  end
end
