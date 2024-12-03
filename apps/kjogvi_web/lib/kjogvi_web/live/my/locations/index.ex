defmodule KjogviWeb.Live.My.Locations.Index do
  @moduledoc false

  use KjogviWeb, :live_view

  alias Kjogvi.Geo

  @impl true
  def mount(_params, _session, socket) do
    locations = Geo.get_upper_level_locations()

    grouped_locations =
      locations
      |> Enum.group_by(&List.last(&1.ancestry))

    top_locations = grouped_locations[nil]

    {
      :ok,
      socket
      |> assign(:page_title, "Locations")
      |> assign(:locations, grouped_locations)
      |> assign(:top_locations, top_locations)
      |> assign(:specials, Geo.get_specials())
    }
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {
      :noreply,
      socket
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- FIXME: Extract to partial --%>
    <.link patch={~p{/my/locations/countries}}>Countries</.link>
    <.link patch={~p{/my/locations}}>Locations</.link>

    <.header_single>
      Locations
    </.header_single>

    <div class="mb-3">
      {render_with_children(%{locations: @top_locations, all_locations: @locations})}
    </div>

    <h2 class="text-lg font-semibold mb-3">Special locations</h2>

    <ul class="list-disc">
      <%= for location <- @specials do %>
        <li class="mb-2">
          <div class="flex gap-3">
            {location_details(%{location: location})}
          </div>
        </li>
      <% end %>
    </ul>
    """
  end

  def render_with_children(assigns) do
    ~H"""
    <ul :if={!is_nil(@locations)}>
      <%= for location <- @locations do %>
        <li class="mb-2">
          <details open class="[&_svg]:open:-rotate-90">
            <summary class="flex gap-3 cursor-pointer mb-2">
              <svg
                class="rotate-0 transform text-blue-700 transition-all duration-300"
                fill="none"
                height="20"
                width="20"
                stroke="currentColor"
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                viewBox="0 0 24 24"
              >
                <polyline points="6 9 12 15 18 9"></polyline>
              </svg>
              {location_details(%{location: location})}
            </summary>
            <div class="ml-8">
              {render_with_children(%{
                locations: @all_locations[location.id],
                all_locations: @all_locations
              })}
            </div>
          </details>
        </li>
      <% end %>
    </ul>
    """
  end

  def location_details(assigns) do
    ~H"""
    <div><strong>{@location.name_en}</strong></div>
    <div class="text-slate-700">{@location.slug}</div>
    <div
      :if={@location.iso_code && @location.iso_code != ""}
      class="text-sm text-slate-500 leading-relaxed"
    >
      <span class="sr-only">ISO alpha-2:</span>
      <span
        class="leading-none font-mono underline text-slate-500 decoration-dotted"
        title="ISO alpha-2"
      >
        {@location.iso_code}
      </span>
    </div>
    <div :if={!is_nil(@location.cards_count)}>{@location.cards_count}</div>
    """
  end
end
