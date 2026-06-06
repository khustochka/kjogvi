defmodule KjogviWeb.Live.Components.AutocompleteTest do
  use KjogviWeb.ConnCase

  import Phoenix.LiveViewTest

  alias KjogviWeb.Live.Components.Autocomplete

  # A minimal host LiveView to render Autocomplete in isolation.
  # Captures messages sent by the component via send(self(), ...).
  #
  # Because live_isolated serializes the session through Plug.Crypto,
  # we can't pass anonymous functions. Instead we pass a "search_mode"
  # string key and resolve the function here.
  defmodule TestLive do
    use Phoenix.LiveView

    alias KjogviWeb.Live.Components.Autocomplete.Highlight

    def render(assigns) do
      ~H"""
      <div>
        <.live_component
          module={Autocomplete}
          id="test_search"
          label={@label}
          placeholder={@placeholder}
          input_value={@input_value}
          search_fn={@search_fn}
          on_select_event={@on_select_event}
          on_select_params={@on_select_params}
          errors={@errors}
          min_length={@min_length}
          clear_on_select={@clear_on_select}
          keep_focus_on_select={@keep_focus_on_select}
        >
          <:result :let={%{result: result, term: term}}>
            <Highlight.highlighted_text text={display(result)} term={term} />
          </:result>
        </.live_component>
        <div id="selected-event">{@last_event}</div>
        <div id="selected-value">{@last_value}</div>
        <div :if={@last_clear_event} id="cleared-event">{@last_clear_event}</div>
      </div>
      """
    end

    def mount(_params, session, socket) do
      assigns = %{
        label: session["label"] || "Search",
        placeholder: session["placeholder"] || "Type to search...",
        input_value: session["input_value"] || "",
        search_fn: resolve_search_fn(session["search_mode"]),
        on_select_event: session["on_select_event"] || "item_selected",
        on_select_params: session["on_select_params"] || %{},
        errors: session["errors"] || [],
        min_length: session["min_length"] || 2,
        clear_on_select: session["clear_on_select"],
        keep_focus_on_select: session["keep_focus_on_select"],
        last_event: "",
        last_value: "",
        last_clear_event: nil
      }

      {:ok, Phoenix.Component.assign(socket, assigns)}
    end

    def handle_info({:autocomplete_select, event, params}, socket) do
      result = params["result"]
      display = display(result)

      {:noreply, Phoenix.Component.assign(socket, last_event: event, last_value: display)}
    end

    def handle_info({:autocomplete_clear, event, _params}, socket) do
      {:noreply, Phoenix.Component.assign(socket, :last_clear_event, event)}
    end

    defp display(result) do
      result[:long_name] || result[:name_en] || inspect(result)
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
      {KjogviWeb.Live.Components.AutocompleteTest.StubSearch, :search}
    end

    defp resolve_search_fn("mfa_tuple") do
      {KjogviWeb.Live.Components.AutocompleteTest.StubSearch, :search_with_context,
       [:some_context]}
    end

    defp resolve_search_fn("raises") do
      fn _query -> raise "boom" end
    end

    defp resolve_search_fn("locations") do
      fn _q -> [%{id: 1, long_name: "Central Park, New York"}] end
    end

    defp resolve_search_fn(_), do: fn _q -> [] end
  end

  # Stub module for testing {module, function} and {module, function, args}
  # search_fn variants.
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
      "input_value" => opts[:input_value],
      "search_mode" => opts[:search_mode] || "parks",
      "on_select_event" => opts[:on_select_event] || "location_selected",
      "on_select_params" => opts[:on_select_params] || %{},
      "errors" => opts[:errors] || [],
      "min_length" => opts[:min_length],
      "clear_on_select" => opts[:clear_on_select] || false,
      "keep_focus_on_select" => opts[:keep_focus_on_select] || false
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

    test "displays input_value when set", %{conn: conn} do
      {_lv, html} = mount_component(conn, %{input_value: "Existing Location"})

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

      lv |> element("#test_search") |> render_keyup(%{"value" => "park"})

      assert has_element?(lv, "#test_search-result-0", "Central")
      assert has_element?(lv, "#test_search-result-1", "Hyde")
    end

    test "shows no dropdown when search has no results", %{conn: conn} do
      {lv, _html} = mount_component(conn)

      lv |> element("#test_search") |> render_keyup(%{"value" => "xyz"})

      refute has_element?(lv, "#test_search-result-0")
      refute has_element?(lv, "#test_search-result-1")
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

      lv |> element("#test_search") |> render_keyup(%{"value" => "park"})
      assert has_element?(lv, "#test_search-result-0")

      lv |> element("#test_search") |> render_keyup(%{"value" => ""})

      refute has_element?(lv, "#test_search-result-0")
    end
  end

  describe "abandon vs clear semantics" do
    test "abandon (Escape) without prior selection does not notify parent", %{conn: conn} do
      {lv, _html} = mount_component(conn)

      lv |> element("#test_search") |> render_keyup(%{"value" => "park"})
      lv |> element("#test_search") |> render_hook("abandon", %{})

      # No selection ever existed → no clear marker propagated to parent.
      refute has_element?(lv, "#cleared-event")
    end

    test "abandon (Escape) with prior selection but non-empty typed text reverts only", %{
      conn: conn
    } do
      {lv, _html} = mount_component(conn, %{input_value: "Existing"})

      lv |> element("#test_search") |> render_keyup(%{"value" => "park"})
      lv |> element("#test_search") |> render_hook("abandon", %{})

      # Typed text was non-empty → revert, not clear.
      refute has_element?(lv, "#cleared-event")
    end

    test "abandon with prior selection AND empty field notifies parent", %{conn: conn} do
      {lv, _html} = mount_component(conn, %{input_value: "Existing"})

      # User backspaces to empty.
      lv |> element("#test_search") |> render_keyup(%{"value" => ""})
      # Then click-away or Escape.
      lv |> element("#test_search") |> render_hook("abandon", %{})

      assert has_element?(lv, "#cleared-event", "location_selected")
    end

    test "explicit clear (× button) with prior selection notifies parent", %{conn: conn} do
      {lv, _html} = mount_component(conn, %{input_value: "Existing"})

      lv |> element("#test_search") |> render_hook("clear", %{})

      assert has_element?(lv, "#cleared-event", "location_selected")
    end

    test "explicit clear without prior selection does not notify parent", %{conn: conn} do
      {lv, _html} = mount_component(conn)

      lv |> element("#test_search") |> render_hook("clear", %{})

      refute has_element?(lv, "#cleared-event")
    end
  end

  describe "clear_on_select" do
    test "empties the field after a pick (click)", %{conn: conn} do
      {lv, _html} = mount_component(conn, %{clear_on_select: true})

      lv |> element("#test_search") |> render_keyup(%{"value" => "park"})
      html = lv |> element("#test_search-result-0") |> render_click()

      # Field is rendered empty, not showing the typed term.
      refute html =~ ~s(value="park")
    end

    test "empties the field after a pick (Enter)", %{conn: conn} do
      {lv, _html} = mount_component(conn, %{clear_on_select: true})

      lv |> element("#test_search") |> render_keyup(%{"value" => "park"})
      html = lv |> element("#test_search") |> render_hook("nav_select", %{})

      refute html =~ ~s(value="park")
    end

    test "with keep_focus_on_select, pushes a client clear event on pick", %{conn: conn} do
      {lv, _html} =
        mount_component(conn, %{clear_on_select: true, keep_focus_on_select: true})

      lv |> element("#test_search") |> render_keyup(%{"value" => "park"})
      lv |> element("#test_search-result-0") |> render_click()

      assert_push_event(lv, "test_search:clear", %{})
    end

    test "without keep_focus_on_select, does not push a client clear event", %{conn: conn} do
      {lv, _html} = mount_component(conn, %{clear_on_select: true})

      lv |> element("#test_search") |> render_keyup(%{"value" => "park"})
      lv |> element("#test_search-result-0") |> render_click()

      refute_push_event(lv, "test_search:clear", %{})
    end
  end

  describe "min_length" do
    test "does not search when query is shorter than min_length", %{conn: conn} do
      {lv, _html} = mount_component(conn, %{search_mode: "hello", min_length: 4})

      lv |> element("#test_search") |> render_keyup(%{"value" => "hel"})

      refute has_element?(lv, "#test_search-result-0")
    end

    test "searches when query meets min_length", %{conn: conn} do
      {lv, _html} = mount_component(conn, %{search_mode: "hello", min_length: 4})

      lv |> element("#test_search") |> render_keyup(%{"value" => "hello"})

      assert has_element?(lv, "#test_search-result-0")
    end

    test "defaults to min_length of 2", %{conn: conn} do
      {lv, _html} = mount_component(conn, %{search_mode: "hello"})

      lv |> element("#test_search") |> render_keyup(%{"value" => "h"})
      refute has_element?(lv, "#test_search-result-0")

      lv |> element("#test_search") |> render_keyup(%{"value" => "hello"})
      assert has_element?(lv, "#test_search-result-0")
    end

    test "clears results when query drops below min_length", %{conn: conn} do
      {lv, _html} = mount_component(conn)

      lv |> element("#test_search") |> render_keyup(%{"value" => "park"})
      assert has_element?(lv, "#test_search-result-0")

      lv |> element("#test_search") |> render_keyup(%{"value" => "p"})
      refute has_element?(lv, "#test_search-result-0")
    end
  end

  describe "focus event" do
    test "re-opens dropdown on focus when results exist", %{conn: conn} do
      {lv, _html} = mount_component(conn)

      lv |> element("#test_search") |> render_keyup(%{"value" => "park"})
      assert has_element?(lv, "#test_search-result-0")

      lv |> element("#test_search") |> render_focus()

      assert has_element?(lv, "#test_search-result-0")
    end
  end

  describe "search_fn variants" do
    test "works with anonymous function", %{conn: conn} do
      {lv, _html} = mount_component(conn, %{search_mode: "hello"})

      lv |> element("#test_search") |> render_keyup(%{"value" => "hello"})

      assert has_element?(lv, "#test_search-result-0", "World")
    end

    test "works with {module, function} tuple", %{conn: conn} do
      {lv, _html} = mount_component(conn, %{search_mode: "mf_tuple"})

      lv |> element("#test_search") |> render_keyup(%{"value" => "match"})

      assert has_element?(lv, "#test_search-result-0", "Result")
    end

    test "works with {module, function, args} tuple", %{conn: conn} do
      {lv, _html} = mount_component(conn, %{search_mode: "mfa_tuple"})

      lv |> element("#test_search") |> render_keyup(%{"value" => "ctx"})

      assert has_element?(lv, "#test_search-result-0", "Result")
    end

    test "returns empty results when search_fn raises", %{conn: conn} do
      {lv, _html} = mount_component(conn, %{search_mode: "raises"})

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
      lv |> element("#test_search") |> render_hook("nav", %{"direction" => "down"})
      lv |> element("#test_search") |> render_hook("nav", %{"direction" => "up"})

      assert has_element?(lv, "#test_search-result-0[data-highlighted]")
      refute has_element?(lv, "#test_search-result-1[data-highlighted]")
    end

    test "highlight does not go below 0", %{conn: conn} do
      {lv, _html} = mount_component(conn)

      lv |> element("#test_search") |> render_keyup(%{"value" => "park"})
      lv |> element("#test_search") |> render_hook("nav", %{"direction" => "up"})

      assert has_element?(lv, "#test_search-result-0[data-highlighted]")
    end

    test "highlight does not exceed last result index", %{conn: conn} do
      {lv, _html} = mount_component(conn)

      lv |> element("#test_search") |> render_keyup(%{"value" => "park"})
      lv |> element("#test_search") |> render_hook("nav", %{"direction" => "down"})
      lv |> element("#test_search") |> render_hook("nav", %{"direction" => "down"})

      assert has_element?(lv, "#test_search-result-1[data-highlighted]")
    end

    test "Enter selects the highlighted result", %{conn: conn} do
      {lv, _html} = mount_component(conn)

      lv |> element("#test_search") |> render_keyup(%{"value" => "park"})
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
      lv |> element("#test_search") |> render_hook("nav", %{"direction" => "down"})
      assert has_element?(lv, "#test_search-result-1[data-highlighted]")

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

      lv |> element("#test_search") |> render_hook("highlight_result", %{"index" => 1})

      refute has_element?(lv, "#test_search-result-0[data-highlighted]")
      assert has_element?(lv, "#test_search-result-1[data-highlighted]")
    end

    test "keyboard works after mouse highlight", %{conn: conn} do
      {lv, _html} = mount_component(conn)

      lv |> element("#test_search") |> render_keyup(%{"value" => "park"})
      lv |> element("#test_search") |> render_hook("highlight_result", %{"index" => 1})
      lv |> element("#test_search") |> render_hook("nav", %{"direction" => "up"})

      assert has_element?(lv, "#test_search-result-0[data-highlighted]")
    end
  end

  describe ":result slot rendering" do
    test "renders slot output for each result", %{conn: conn} do
      {lv, _html} = mount_component(conn, %{search_mode: "locations"})

      lv |> element("#test_search") |> render_keyup(%{"value" => "park"})

      assert has_element?(lv, "#test_search-result-0", "Central")
      assert has_element?(lv, "#test_search-result-0", "New York")
    end

    test "highlights matching term in results via Highlight helper", %{conn: conn} do
      {lv, _html} = mount_component(conn)

      lv |> element("#test_search") |> render_keyup(%{"value" => "park"})

      assert has_element?(lv, "#test_search-result-0 strong", "Park")
    end
  end
end
