defmodule KjogviWeb.Live.Lifelist.Index do
  use KjogviWeb, :live_view

  alias Kjogvi.Birding

  @impl true
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
    }
  end

  @impl true
  def handle_params(params, _url, socket) do
    filter = KjogviWeb.Live.Lifelist.Params.to_filter(params)
    lifelist = Birding.Lifelist.generate(filter)

    {
      :noreply,
      socket
      |> assign(
        lifelist: lifelist,
        total: length(lifelist),
        year: filter[:year],
        location: filter[:location],
        years: Birding.Lifelist.years(Map.delete(filter, :year)),
        locations: Kjogvi.Geo.get_countries()
      )
      |> derive_page_header()
      |> derive_page_title()
      |> derive_robots()
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <%= @page_header %>
    </.header>
    <p class="mt-4">
      Total of <%= @total %> species.
    </p>

    <ul class="flex flex-wrap gap-x-4 gap-y-2 mt-4">
      <li class="whitespace-nowrap">
        <b :if={is_nil(@year)}>All years</b>
        <.link :if={not is_nil(@year)} patch={lifelist_path(nil, @location)}>All years</.link>
      </li>
      <%= for year <- @years do %>
        <li>
          <b :if={@year == year}><%= year %></b>
          <.link :if={@year != year} patch={lifelist_path(year, @location)}><%= year %></.link>
        </li>
      <% end %>
    </ul>

    <ul class="flex flex-wrap gap-x-4 gap-y-2 mt-4">
      <li class="whitespace-nowrap">
        <b :if={is_nil(@location)}>All countries</b>
        <.link :if={not is_nil(@location)} patch={lifelist_path(@year, nil)}>All countries</.link>
      </li>
      <%= for location <- @locations do %>
        <li>
          <b :if={@location == location}><%= location.name_en %></b>
          <.link :if={@location != location} patch={lifelist_path(@year, location)}><%= location.name_en %></.link>
        </li>
      <% end %>
    </ul>

    <table id="lifers" class="mt-11 w-full">
      <thead class="text-sm text-left leading-6 text-zinc-500">
        <tr>
          <th class="p-0 pr-6 pb-4 font-normal"></th>
          <th class="p-0 pr-6 pb-4 font-normal">Species</th>
          <th class="p-0 pr-6 pb-4 font-normal text-center">Date</th>
          <th class="p-0 pr-6 pb-4 font-normal">Location</th>
          <th class="p-0 pr-6 pb-4 font-normal">Country</th>
          <th class="p-0 pr-6 pb-4 font-normal text-center">Card</th>
        </tr>
      </thead>
      <tbody class="divide-y divide-zinc-100 border-t border-zinc-200 text-sm leading-6 text-zinc-700">
        <%= for {lifer, i} <- Enum.with_index(@lifelist) do %>
          <tr>
            <td class="p-0 py-4 pr-6 text-right"><%= @total - i %>.</td>
            <td class="p-0 py-4 pr-6">
              <strong><%= lifer.species.name_en %></strong>
              <i><%= lifer.species.name_sci %></i>
            </td>
            <td class="p-0 py-4 pr-6 text-center whitespace-nowrap">
              <%= lifer.observ_date %>
            </td>
            <td class="p-0 py-4 pr-6"><%= lifer.location.name_en %></td>
            <td class="p-0 py-4 pr-6">
              <%= if lifer.location.country do %>
                <%= lifer.location.country.name_en %>
              <% end %>
            </td>
            <td class="p-0 py-4 pr-6 text-center">
              <.link navigate={~p"/cards/#{lifer.card_id}"}>
                <.icon name="hero-clipboard-document-list" class="w-[18px]" />
              </.link>
            </td>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end

  defp lifelist_title(%{year: nil, location: nil}) do
    "Lifelist"
  end

  defp lifelist_title(%{year: year, location: nil}) when is_integer(year) do
    "#{year} Year List"
  end

  defp lifelist_title(%{year: nil, location: location}) do
    "#{location.name_en} Life List"
  end

  defp lifelist_title(%{year: year, location: location}) when is_integer(year) do
    "#{year} #{location.name_en} List"
  end

  defp derive_page_header(socket) do
    socket
    |> assign(:page_header, lifelist_title(socket.assigns))
  end

  defp derive_page_title(%{assigns: assigns} = socket) do
    socket
    |> assign(:page_title, assigns[:page_header] || lifelist_title(assigns))
  end

  defp derive_robots(%{assigns: %{year: nil}} = socket) do
    socket
  end

  defp derive_robots(%{assigns: %{lifelist: []}} = socket) do
    socket
    |> assign(:robots, [:noindex])
  end

  defp derive_robots(socket) do
    socket
  end

  defp lifelist_path(_year = nil, _location = nil) do
    ~p"/lifelist"
  end

  defp lifelist_path(year, _location = nil) do
    ~p"/lifelist/#{year}"
  end

  defp lifelist_path(_year = nil, location) do
    ~p"/lifelist/#{location.slug}"
  end

  defp lifelist_path(year, location) do
    ~p"/lifelist/#{year}/#{location.slug}"
  end
end
