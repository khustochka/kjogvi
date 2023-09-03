defmodule KjogviWeb.LifelistLive.Index do
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
    year =
      case params["year"] do
        str when is_binary(str) -> String.to_integer(str)
        val when is_integer(val) or is_nil(val) -> val
      end

    lifelist = Birding.Lifelist.generate(year: year)
    title = lifelist_title(params)
    years = Birding.Lifelist.years(year: year)

    {
      :noreply,
      socket
      |> assign(:lifelist, lifelist)
      |> assign(:total, length(lifelist))
      |> assign(:year, year)
      |> assign(:years, years)
      |> assign(:page_header, title)
      |> assign(:page_title, title)
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
        <.link :if={not is_nil(@year)} patch={~p"/lifelist"}>All years</.link>
      </li>
      <%= for year <- @years do %>
        <li>
          <b :if={@year == year}><%= year %></b>
          <.link :if={@year != year} patch={~p"/lifelist/#{year}"}><%= year %></.link>
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

  def lifelist_title(%{"year" => year} = _params) when not is_nil(year) do
    "#{year} Year List"
  end

  def lifelist_title(_) do
    "Lifelist"
  end
end
