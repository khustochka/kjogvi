defmodule KjogviWeb.Live.Components.Autocomplete.SearchInput do
  @moduledoc """
  `<input type="search">` wired up to the global `SearchInput` JS hook,
  with a leading magnifying-glass icon and a trailing × clear button.

  Pushes two events to the LiveView/LiveComponent identified by
  `:target` (omit `:target` to deliver to the enclosing LiveView). The
  event *names* are supplied by the caller via `:on_search` and
  `:on_clear`:

    * `:on_search` — sent on every keyup, payload `%{"value" => query}`
    * `:on_clear`  — sent when the user clicks the × button or empties
      the field by other means

  Mandatory naming exists because two `SearchInput`s on the same page
  targeting the same LiveView would otherwise collide. Pick names that
  describe what the LiveView does on each event (e.g.
  `on_search="filter_locations"`, `on_clear="clear_location_filter"`).

  Reusable for any search-as-you-type box. Use `Autocomplete` when you
  also want a dropdown of results, keyboard navigation, and selection;
  it sets `:hook` to `"AutocompletePicker"` to install the keyboard /
  highlight / scroll-into-view behaviour. Standalone callers leave
  `:hook` at its default (`nil`) and no JS hook is attached.

  The browser's native search × is hidden via base CSS so this
  component's custom × is the only one shown — consistent across
  Chrome/Edge/Firefox/Safari.

  Set `:icon` to any Heroicon name (default `"hero-magnifying-glass"`);
  pass `nil` to omit the leading icon (no left-padding offset).
  """

  use KjogviWeb, :html

  attr :id, :string, required: true
  attr :on_search, :string, required: true, doc: "event name pushed on keyup"
  attr :on_clear, :string, required: true, doc: "event name pushed when the field is cleared"

  attr :target, :any,
    default: nil,
    doc: "phx-target for events; omit to deliver to the enclosing LiveView"

  attr :placeholder, :string, default: ""
  attr :value, :string, default: ""
  attr :debounce, :string, default: "300"
  attr :compact, :boolean, default: false
  attr :has_errors, :boolean, default: false

  attr :icon, :string,
    default: "hero-magnifying-glass",
    doc: "leading Heroicon name; pass `nil` to omit"

  attr :hook, :string,
    default: nil,
    doc: "optional JS hook name (e.g. `AutocompletePicker` for full picker)"

  attr :rest, :global

  def search_input(assigns) do
    ~H"""
    <div class="relative">
      <.icon
        :if={@icon}
        name={@icon}
        class="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-400"
      />
      <input
        type="search"
        id={@id}
        placeholder={@placeholder}
        phx-target={@target}
        phx-hook={@hook}
        phx-keyup={@on_search}
        phx-debounce={@debounce}
        autocomplete="off"
        value={@value}
        class={[
          "block w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6",
          @compact && @icon && "pl-7 pr-7 py-1",
          @compact && !@icon && "pl-2 pr-7 py-1",
          !@compact && @icon && "pl-9 pr-9",
          !@compact && !@icon && "pr-9",
          !@has_errors && "border-zinc-300 focus:border-zinc-400",
          @has_errors && "border-rose-400 focus:border-rose-400"
        ]}
        {@rest}
      />
      <button
        :if={@value != ""}
        type="button"
        phx-target={@target}
        phx-click={@on_clear}
        aria-label="Clear"
        class={[
          "absolute top-1/2 -translate-y-1/2 text-zinc-400 hover:text-zinc-600",
          @compact && "right-1.5",
          !@compact && "right-2.5"
        ]}
      >
        <.icon name="hero-x-mark" class="w-4 h-4" />
      </button>
    </div>
    """
  end
end
