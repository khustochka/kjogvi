defmodule KjogviWeb.Live.My.Locations.Index do
  @moduledoc false

  use KjogviWeb, :live_view

  alias Kjogvi.Geo

  @impl true
  def mount(_params, _session, socket) do
    locations = Geo.get_upper_level_locations()

    top_locations =
      locations
      |> Enum.filter(fn loc -> loc.ancestry == [] end)

    {
      :ok,
      socket
      |> assign(:page_title, "Locations")
      |> assign(:locations, locations)
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
      <%= render_with_children(%{locations: @top_locations, all_locations: @locations}) %>
    </div>

    <h2 class="text-lg font-semibold">Special locations</h2>

    <ul>
      <%= for location <- @specials do %>
        <li>
          <div class="flex gap-2">
            <div><%= location.id %></div>
            <div><%= location.slug %></div>
            <div><%= location.name_en %></div>
            <div><%= location.cards_count %></div>
          </div>
        </li>
      <% end %>
    </ul>
    """
  end

  def render_with_children(assigns) do
    ~H"""
    <ul class="hs-accordion-group" data-hs-accordion-always-open="data-hs-accordion-always-open">
      <%= for location <- @locations do %>
        <li class="hs-accordion active">
          <button
            class="hs-accordion-toggle hs-accordion-active:text-blue-600 py-3 inline-flex items-center gap-x-3 w-full font-semibold text-start text-gray-800 hover:text-gray-500 focus:outline-none focus:text-gray-500 rounded-lg disabled:opacity-50 disabled:pointer-events-none dark:hs-accordion-active:text-blue-500 dark:text-neutral-200 dark:hover:text-neutral-400 dark:focus:text-neutral-400"
            aria-expanded="true"
            aria-controls="hs-basic-nested-collapse-one"
          >
            <svg
              class="hs-accordion-active:hidden block size-3.5"
              xmlns="http://www.w3.org/2000/svg"
              width="24"
              height="24"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path d="M5 12h14"></path>
              <path d="M12 5v14"></path>
            </svg>
            <svg
              class="hs-accordion-active:block hidden size-3.5"
              xmlns="http://www.w3.org/2000/svg"
              width="24"
              height="24"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path d="M5 12h14"></path>
            </svg>
            <div class="flex gap-2">
              <div><%= location.name_en %></div>
              <div class="font-normal"><%= location.slug %></div>
              <div><%= location.cards_count %></div>
            </div>
          </button>
          <div class="hs-accordion-content w-full overflow-hidden transition-[height] duration-300">
            <div class="ml-8">
              <%= render_with_children(%{
                locations:
                  Enum.filter(@all_locations, fn loc -> List.last(loc.ancestry) == location.id end),
                all_locations: @all_locations
              }) %>
            </div>
          </div>
        </li>
      <% end %>
    </ul>
    """
  end
end
