defmodule KjogviWeb.Live.Components.AutocompleteSearchTest do
  use KjogviWeb.ConnCase

  import Phoenix.LiveViewTest

  alias KjogviWeb.Live.Components.AutocompleteSearch

  # A minimal host LiveView to render AutocompleteSearch in isolation.
  # Captures messages sent by the component via send(self(), ...).
  #
  # Because live_isolated serializes the session through Plug.Crypto,
  # we can't pass anonymous functions. Instead we pass a "search_mode"
  # string key and resolve the function here.
  defmodule TestLive do
    use Phoenix.LiveView

    def render(assigns) do
      ~H"""
      <div>
        <.live_component
          module={AutocompleteSearch}
          id="test_search"
          label={@label}
          placeholder={@placeholder}
          current_value={@current_value}
          hidden_name={@hidden_name}
          hidden_value={@hidden_value}
          search_fn={@search_fn}
          on_select_event={@on_select_event}
          on_select_params={@on_select_params}
          errors={@errors}
        />
        <div id="selected-event">{@last_event}</div>
        <div id="selected-value">{@last_value}</div>
      </div>
      """
    end

    def mount(_params, session, socket) do
      assigns = %{
        label: session["label"] || "Search",
        placeholder: session["placeholder"] || "Type to search...",
        current_value: session["current_value"],
        hidden_name: session["hidden_name"] || "item[id]",
        hidden_value: session["hidden_value"] || "",
        search_fn: resolve_search_fn(session["search_mode"]),
        on_select_event: session["on_select_event"] || "item_selected",
        on_select_params: session["on_select_params"] || %{},
        errors: session["errors"] || [],
        last_event: "",
        last_value: ""
      }

      {:ok, Phoenix.Component.assign(socket, assigns)}
    end

    def handle_info({:autocomplete_select, event, params}, socket) do
      result = params["result"]
      display = result[:long_name] || result[:name_en] || inspect(result)

      {:noreply, Phoenix.Component.assign(socket, last_event: event, last_value: display)}
    end

    # Predefined search functions, selected by session key
    defp resolve_search_fn("parks") do
      fn query ->
        if String.contains?(query, "park") do
          [%{id: 1, long_name: "Central Park"}, %{id: 2, long_name: "Hyde Park"}]
        else
          []
        end
      end
    end

    defp resolve_search_fn("hello") do
      fn query ->
        if query == "hello", do: [%{id: 1, long_name: "Hello World"}], else: []
      end
    end

    defp resolve_search_fn("mf_tuple") do
      {KjogviWeb.Live.Components.AutocompleteSearchTest.StubSearch, :search}
    end

    defp resolve_search_fn("mfa_tuple") do
      {KjogviWeb.Live.Components.AutocompleteSearchTest.StubSearch, :search_with_context,
       [:some_context]}
    end

    defp resolve_search_fn("raises") do
      fn _query -> raise "boom" end
    end

    defp resolve_search_fn("locations") do
      fn _q -> [%{id: 1, long_name: "Central Park, New York"}] end
    end

    defp resolve_search_fn("taxa") do
      fn _q ->
        [%{id: 1, name_en: "House Sparrow", name_sci: "Passer domesticus"}]
      end
    end

    defp resolve_search_fn("unknown_shape") do
      fn _q -> [%{id: 1, custom_field: "something"}] end
    end

    defp resolve_search_fn(_), do: fn _q -> [] end
  end

  # Stub module for testing {module, function} and {module, function, args} search_fn variants
  defmodule StubSearch do
    def search(query) do
      if String.contains?(query, "match") do
        [%{id: 1, long_name: "Match Result"}]
      else
        []
      end
    end

    def search_with_context(_context, query) do
      if String.contains?(query, "ctx") do
        [%{id: 2, long_name: "Context Result"}]
      else
        []
      end
    end
  end

  @endpoint KjogviWeb.Endpoint

  defp mount_component(conn, opts \\ %{}) do
    session = %{
      "label" => opts[:label] || "Location",
      "placeholder" => opts[:placeholder] || "Search locations...",
      "current_value" => opts[:current_value],
      "hidden_name" => opts[:hidden_name] || "card[location_id]",
      "hidden_value" => opts[:hidden_value] || "",
      "search_mode" => opts[:search_mode] || "parks",
      "on_select_event" => opts[:on_select_event] || "location_selected",
      "on_select_params" => opts[:on_select_params] || %{},
      "errors" => opts[:errors] || []
    }

    {:ok, lv, html} = live_isolated(conn, TestLive, session: session)
    {lv, html}
  end

  describe "rendering" do
    test "renders label and search input", %{conn: conn} do
      {_lv, html} = mount_component(conn, %{label: "Location"})

      assert html =~ "Location"
      assert html =~ "Search locations..."
    end

    test "renders hidden input with correct name", %{conn: conn} do
      {_lv, html} = mount_component(conn, %{hidden_name: "card[location_id]"})

      assert html =~ "card[location_id]"
      assert html =~ "type=\"hidden\""
    end

    test "displays current_value when set", %{conn: conn} do
      {_lv, html} = mount_component(conn, %{current_value: "Existing Location"})

      assert html =~ "Existing Location"
    end

    test "renders errors when present", %{conn: conn} do
      {_lv, html} = mount_component(conn, %{errors: ["can't be blank"]})

      assert html =~ "can" <> "&#39;" <> "t be blank"
    end

    test "renders error styling on input when errors present", %{conn: conn} do
      {_lv, html} = mount_component(conn, %{errors: ["required"]})

      assert html =~ "border-rose-400"
    end

    test "renders normal styling on input when no errors", %{conn: conn} do
      {_lv, html} = mount_component(conn)

      assert html =~ "border-zinc-300"
    end
  end

  describe "search event" do
    test "shows results when search matches", %{conn: conn} do
      {lv, _html} = mount_component(conn)

      html = lv |> element("#test_search") |> render_keyup(%{"value" => "park"})

      assert html =~ "Central Park"
      assert html =~ "Hyde Park"
    end

    test "shows no dropdown when search has no results", %{conn: conn} do
      {lv, _html} = mount_component(conn)

      html = lv |> element("#test_search") |> render_keyup(%{"value" => "xyz"})

      refute html =~ "Central Park"
      refute html =~ "Hyde Park"
    end

    test "generates result elements with predictable IDs", %{conn: conn} do
      {lv, _html} = mount_component(conn)

      lv |> element("#test_search") |> render_keyup(%{"value" => "park"})

      assert has_element?(lv, "#test_search-result-0")
      assert has_element?(lv, "#test_search-result-1")
    end
  end

  describe "select_result event" do
    test "sends selection message to parent", %{conn: conn} do
      {lv, _html} = mount_component(conn)

      lv |> element("#test_search") |> render_keyup(%{"value" => "park"})
      lv |> element("#test_search-result-0") |> render_click()

      # Parent should have received the event and rendered it
      assert has_element?(lv, "#selected-event", "location_selected")
      assert has_element?(lv, "#selected-value", "Central Park")
    end

    test "clears results after selection", %{conn: conn} do
      {lv, _html} = mount_component(conn)

      lv |> element("#test_search") |> render_keyup(%{"value" => "park"})
      lv |> element("#test_search-result-0") |> render_click()

      refute has_element?(lv, "#test_search-result-0")
    end

    test "includes on_select_params in selection message", %{conn: conn} do
      {lv, _html} =
        mount_component(conn, %{
          on_select_event: "taxon_selected",
          on_select_params: %{"index" => "0"}
        })

      lv |> element("#test_search") |> render_keyup(%{"value" => "park"})
      lv |> element("#test_search-result-0") |> render_click()

      assert has_element?(lv, "#selected-event", "taxon_selected")
    end
  end

  describe "clear event" do
    test "empty search clears results", %{conn: conn} do
      {lv, _html} = mount_component(conn)

      # Open results
      lv |> element("#test_search") |> render_keyup(%{"value" => "park"})
      assert has_element?(lv, "#test_search-result-0")

      # Search with empty value returns no results, closing dropdown
      lv |> element("#test_search") |> render_keyup(%{"value" => ""})

      refute has_element?(lv, "#test_search-result-0")
    end
  end

  describe "focus event" do
    test "re-opens dropdown on focus when results exist", %{conn: conn} do
      {lv, _html} = mount_component(conn)

      # Search to get results
      lv |> element("#test_search") |> render_keyup(%{"value" => "park"})
      assert has_element?(lv, "#test_search-result-0")

      # Focus should keep results visible
      lv |> element("#test_search") |> render_focus()

      assert has_element?(lv, "#test_search-result-0")
    end
  end

  describe "search_fn variants" do
    test "works with anonymous function", %{conn: conn} do
      {lv, _html} = mount_component(conn, %{search_mode: "hello"})

      html = lv |> element("#test_search") |> render_keyup(%{"value" => "hello"})
      assert html =~ "Hello World"
    end

    test "works with {module, function} tuple", %{conn: conn} do
      {lv, _html} = mount_component(conn, %{search_mode: "mf_tuple"})

      html = lv |> element("#test_search") |> render_keyup(%{"value" => "match"})
      assert html =~ "Match Result"
    end

    test "works with {module, function, args} tuple", %{conn: conn} do
      {lv, _html} = mount_component(conn, %{search_mode: "mfa_tuple"})

      html = lv |> element("#test_search") |> render_keyup(%{"value" => "ctx"})
      assert html =~ "Context Result"
    end

    test "returns empty results when search_fn raises", %{conn: conn} do
      {lv, _html} = mount_component(conn, %{search_mode: "raises"})

      # Should not crash, just show no results
      refute has_element?(lv, "#test_search-result-0")

      lv |> element("#test_search") |> render_keyup(%{"value" => "anything"})

      refute has_element?(lv, "#test_search-result-0")
    end
  end

  describe "keyboard navigation" do
    test "first result is highlighted by default", %{conn: conn} do
      {lv, _html} = mount_component(conn)

      lv |> element("#test_search") |> render_keyup(%{"value" => "park"})

      assert has_element?(lv, "#test_search-result-0[data-highlighted]")
      refute has_element?(lv, "#test_search-result-1[data-highlighted]")
    end

    test "ArrowDown moves highlight down", %{conn: conn} do
      {lv, _html} = mount_component(conn)

      lv |> element("#test_search") |> render_keyup(%{"value" => "park"})
      lv |> element("#test_search") |> render_hook("nav", %{"direction" => "down"})

      refute has_element?(lv, "#test_search-result-0[data-highlighted]")
      assert has_element?(lv, "#test_search-result-1[data-highlighted]")
    end

    test "ArrowUp moves highlight up", %{conn: conn} do
      {lv, _html} = mount_component(conn)

      lv |> element("#test_search") |> render_keyup(%{"value" => "park"})
      # Move down first, then up
      lv |> element("#test_search") |> render_hook("nav", %{"direction" => "down"})
      lv |> element("#test_search") |> render_hook("nav", %{"direction" => "up"})

      assert has_element?(lv, "#test_search-result-0[data-highlighted]")
      refute has_element?(lv, "#test_search-result-1[data-highlighted]")
    end

    test "highlight does not go below 0", %{conn: conn} do
      {lv, _html} = mount_component(conn)

      lv |> element("#test_search") |> render_keyup(%{"value" => "park"})
      # Already at 0, try to go up
      lv |> element("#test_search") |> render_hook("nav", %{"direction" => "up"})

      assert has_element?(lv, "#test_search-result-0[data-highlighted]")
    end

    test "highlight does not exceed last result index", %{conn: conn} do
      {lv, _html} = mount_component(conn)

      # "parks" mode returns 2 results (indexes 0 and 1)
      lv |> element("#test_search") |> render_keyup(%{"value" => "park"})
      lv |> element("#test_search") |> render_hook("nav", %{"direction" => "down"})
      lv |> element("#test_search") |> render_hook("nav", %{"direction" => "down"})

      # Should still be at index 1 (last result)
      assert has_element?(lv, "#test_search-result-1[data-highlighted]")
    end

    test "Enter selects the highlighted result", %{conn: conn} do
      {lv, _html} = mount_component(conn)

      lv |> element("#test_search") |> render_keyup(%{"value" => "park"})
      # Move to second result
      lv |> element("#test_search") |> render_hook("nav", %{"direction" => "down"})
      lv |> element("#test_search") |> render_hook("nav_select", %{})

      assert has_element?(lv, "#selected-event", "location_selected")
      assert has_element?(lv, "#selected-value", "Hyde Park")
    end

    test "Enter selects first result by default", %{conn: conn} do
      {lv, _html} = mount_component(conn)

      lv |> element("#test_search") |> render_keyup(%{"value" => "park"})
      lv |> element("#test_search") |> render_hook("nav_select", %{})

      assert has_element?(lv, "#selected-event", "location_selected")
      assert has_element?(lv, "#selected-value", "Central Park")
    end

    test "highlight resets to 0 on new search", %{conn: conn} do
      {lv, _html} = mount_component(conn)

      lv |> element("#test_search") |> render_keyup(%{"value" => "park"})
      # Move highlight down
      lv |> element("#test_search") |> render_hook("nav", %{"direction" => "down"})
      assert has_element?(lv, "#test_search-result-1[data-highlighted]")

      # New search resets highlight
      lv |> element("#test_search") |> render_keyup(%{"value" => "parks"})

      assert has_element?(lv, "#test_search-result-0[data-highlighted]")
    end

    test "nav_select clears results after selection", %{conn: conn} do
      {lv, _html} = mount_component(conn)

      lv |> element("#test_search") |> render_keyup(%{"value" => "park"})
      lv |> element("#test_search") |> render_hook("nav_select", %{})

      refute has_element?(lv, "#test_search-result-0")
    end

    test "mouseenter moves highlight to hovered result", %{conn: conn} do
      {lv, _html} = mount_component(conn)

      lv |> element("#test_search") |> render_keyup(%{"value" => "park"})
      assert has_element?(lv, "#test_search-result-0[data-highlighted]")

      # JS.push targets the component — simulate via the hooked input element
      lv |> element("#test_search") |> render_hook("highlight_result", %{"index" => 1})

      refute has_element?(lv, "#test_search-result-0[data-highlighted]")
      assert has_element?(lv, "#test_search-result-1[data-highlighted]")
    end

    test "keyboard works after mouse highlight", %{conn: conn} do
      {lv, _html} = mount_component(conn)

      lv |> element("#test_search") |> render_keyup(%{"value" => "park"})
      # Mouse moves to second result
      lv |> element("#test_search") |> render_hook("highlight_result", %{"index" => 1})
      # Keyboard moves back up
      lv |> element("#test_search") |> render_hook("nav", %{"direction" => "up"})

      assert has_element?(lv, "#test_search-result-0[data-highlighted]")
    end
  end

  describe "result_display" do
    test "displays long_name for location-like results", %{conn: conn} do
      {lv, _html} = mount_component(conn, %{search_mode: "locations"})

      html = lv |> element("#test_search") |> render_keyup(%{"value" => "park"})
      assert html =~ "Central Park, New York"
    end

    test "displays name_en and name_sci for taxon-like results", %{conn: conn} do
      {lv, _html} = mount_component(conn, %{search_mode: "taxa"})

      html = lv |> element("#test_search") |> render_keyup(%{"value" => "sparrow"})
      assert html =~ "House Sparrow"
      assert html =~ "Passer domesticus"
    end

    test "falls back to inspect for unknown result shapes", %{conn: conn} do
      {lv, _html} = mount_component(conn, %{search_mode: "unknown_shape"})

      html = lv |> element("#test_search") |> render_keyup(%{"value" => "any"})
      assert html =~ "custom_field"
    end
  end
end
