defmodule KjogviWeb.Live.Lifelist.Index do
  @moduledoc false

  use KjogviWeb, :live_view

  alias Kjogvi.Util
  alias Kjogvi.Birding
  alias Kjogvi.Geo

  alias KjogviWeb.Format

  @impl true
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
    }
  end

  @impl true
  def handle_params(params, _url, socket) do
    filter =
      KjogviWeb.Live.Lifelist.Params.to_filter(socket.assigns.current_user, params)
      |> case do
        {:ok, filter} -> filter
        {:error, _} -> raise Plug.BadRequestError
      end

    lifelist = Birding.Lifelist.generate(filter)

    all_years = Birding.Lifelist.years()

    years =
      Birding.Lifelist.years(Map.delete(filter, :year))
      |> then(&Util.Enum.zip_inclusion(all_years, &1))

    all_countries = Kjogvi.Geo.get_countries()
    country_ids = Birding.Lifelist.country_ids(Map.delete(filter, :location))

    locations =
      all_countries
      |> Enum.map(fn el -> {el, el.id in country_ids} end)

    {
      :noreply,
      socket
      |> assign(
        public_view: derive_public_view(socket, params),
        lifelist: lifelist,
        filter: filter,
        total: length(lifelist),
        years: years,
        months: 1..12,
        locations: locations
      )
      |> derive_current_path_query()
      |> derive_location_field()
      |> derive_page_header()
      |> derive_page_title()
      |> derive_robots()
    }
  end

  @impl true
  def handle_event(
        "public_toggle",
        %{"_target" => ["public_view"]} = params,
        %{assigns: assigns} = socket
      ) do
    {:noreply,
     push_navigate(socket,
       to:
         lifelist_path(
           assigns.filter,
           Keyword.put(
             assigns.current_path_query,
             :public_view,
             derive_public_view(socket, params)
           )
         )
     )}
  end

  @impl true
  @spec render(any()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <.header_single font_style={header_style(assigns)}>
      <%= @page_header %>
    </.header_single>

    <div :if={@current_user} class="flex items-center mt-4">
      <form action="" phx-change="public_toggle">
        <input type="hidden" name="public_view" />
        <input
          type="checkbox"
          name="public_view"
          value="true"
          checked={@public_view}
          id="hs-basic-with-description-unchecked"
          class="relative w-[3.25rem] h-7 p-px bg-gray-100 border-transparent text-transparent rounded-full cursor-pointer transition-colors ease-in-out duration-200 focus:ring-blue-600 disabled:opacity-50 disabled:pointer-events-none checked:bg-none checked:text-blue-600 checked:border-blue-600 focus:checked:border-blue-600 dark:bg-gray-800 dark:border-gray-700 dark:checked:bg-blue-500 dark:checked:border-blue-500 dark:focus:ring-offset-gray-600 before:inline-block before:w-6 before:h-6 before:bg-white checked:before:bg-blue-200 before:translate-x-0 checked:before:translate-x-full before:rounded-full before:shadow before:transform before:ring-0 before:transition before:ease-in-out before:duration-200 dark:before:bg-gray-400 dark:checked:before:bg-blue-200"
        />
        <label
          for="hs-basic-with-description-unchecked"
          class="text-sm text-gray-500 ms-3 dark:text-gray-400"
        >
          Public view
        </label>
      </form>
    </div>

    <ul class="flex flex-wrap gap-x-4 gap-y-2 mt-4">
      <li class="whitespace-nowrap">
        <em :if={!@filter.motorless} class="font-semibold not-italic">Include all</em>
        <.link
          :if={@filter.motorless}
          patch={lifelist_path(%{@filter | motorless: false}, @current_path_query)}
        >
          Include all
        </.link>
      </li>
      <li class="whitespace-nowrap">
        <em :if={@filter.motorless} class="font-semibold not-italic">Motorless only</em>
        <.link
          :if={!@filter.motorless}
          patch={lifelist_path(%{@filter | motorless: true}, @current_path_query)}
        >
          Motorless only
        </.link>
      </li>
    </ul>

    <ul class="flex flex-wrap gap-x-4 gap-y-2 mt-4">
      <li class="whitespace-nowrap">
        <em :if={is_nil(@filter.year)} class="font-semibold not-italic">All years</em>
        <.link
          :if={not is_nil(@filter.year)}
          patch={lifelist_path(%{@filter | year: nil}, @current_path_query)}
        >
          All years
        </.link>
      </li>
      <%= for {year, active} <- @years do %>
        <li>
          <%= if @filter.year == year do %>
            <em class="font-semibold not-italic"><%= year %></em>
          <% else %>
            <%= if active do %>
              <.link patch={lifelist_path(%{@filter | year: year}, @current_path_query)}>
                <%= year %>
              </.link>
            <% else %>
              <span class="text-gray-500"><%= year %></span>
            <% end %>
          <% end %>
        </li>
      <% end %>
    </ul>

    <ul class="flex flex-wrap gap-x-4 gap-y-2 mt-4">
      <li class="whitespace-nowrap">
        <em :if={is_nil(@filter.month)} class="font-semibold not-italic">All months</em>
        <.link
          :if={not is_nil(@filter.month)}
          patch={lifelist_path(%{@filter | month: nil}, Keyword.delete(@current_path_query, :month))}
        >
          All months
        </.link>
      </li>
      <%= for month <- @months do %>
        <li>
          <%= if @filter.month == month do %>
            <em class="font-semibold not-italic"><%= Timex.month_shortname(month) %></em>
          <% else %>
            <.link patch={
              lifelist_path(
                %{@filter | month: month},
                Keyword.put(@current_path_query, :month, month)
              )
            }>
              <%= Timex.month_shortname(month) %>
            </.link>
          <% end %>
        </li>
      <% end %>
    </ul>

    <ul class="flex flex-wrap gap-x-4 gap-y-2 mt-4">
      <li class="whitespace-nowrap">
        <em :if={is_nil(@filter.location)} class="font-semibold not-italic">All countries</em>
        <.link
          :if={not is_nil(@filter.location)}
          patch={lifelist_path(%{@filter | location: nil}, @current_path_query)}
        >
          All countries
        </.link>
      </li>
      <%= for {location, active} <- @locations do %>
        <li>
          <%= if @filter.location == location do %>
            <em class="font-semibold not-italic"><%= location.name_en %></em>
          <% else %>
            <%= if active do %>
              <.link patch={lifelist_path(%{@filter | location: location}, @current_path_query)}>
                <%= location.name_en %>
              </.link>
            <% else %>
              <span class="text-gray-500"><%= location.name_en %></span>
            <% end %>
          <% end %>
        </li>
      <% end %>
    </ul>

    <table id="lifers" class="mt-11 w-full">
      <thead class="text-sm text-left leading-snug text-zinc-500">
        <tr>
          <th class="p-0 pr-6 pb-4 font-normal"></th>
          <th class="p-0 pr-6 pb-4 font-normal">Species</th>
          <th class="p-0 pr-6 pb-4 font-normal text-center">Date</th>
          <th class="p-0 pr-6 pb-4 font-normal">Location</th>
          <th :if={!@public_view} class="p-0 pr-6 pb-4 font-normal text-center">Card</th>
        </tr>
      </thead>
      <tbody class="divide-y divide-zinc-100 border-t border-zinc-200 leading-snug text-zinc-700">
        <%= for {lifer, i} <- Enum.with_index(@lifelist) do %>
          <tr>
            <td class="p-0 py-4 pr-6 text-right"><%= @total - i %>.</td>
            <td class="p-0 py-4 pr-6">
              <strong class="font-bold"><%= lifer.species.name_en %></strong>
              <i class="whitespace-nowrap"><%= lifer.species.name_sci %></i>
            </td>
            <td class="p-0 py-4 pr-6 text-center whitespace-nowrap">
              <%= Format.observation_date(lifer) %>
            </td>
            <td class="p-0 py-4 pr-6">
              <%= with location <- get_in(lifer, [Access.key!(@location_field)]) do %>
                <%= Geo.Location.name_local_part(location) %> ·
                <%= with country when not is_nil(country) <- location.country do %>
                  <span class="font-semibold whitespace-nowrap">
                    <%= Geo.Location.name_administrative_part(location) %>
                  </span>
                <% end %>
              <% end %>
            </td>
            <td :if={!@public_view} class="p-0 py-4 pr-6 text-center">
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

  defp lifelist_title(%{year: nil, location: nil, month: nil}) do
    "Lifelist"
  end

  defp lifelist_title(%{year: nil, location: nil, month: month}) do
    "#{Timex.month_name(month)} Lifelist"
  end

  defp lifelist_title(%{year: year, location: nil, month: nil}) do
    "#{year} Year List"
  end

  defp lifelist_title(%{year: year, location: nil, month: month}) do
    "#{Timex.month_name(month)} #{year} List"
  end

  defp lifelist_title(%{year: nil, location: location, month: nil}) do
    "#{location.name_en} Life List"
  end

  defp lifelist_title(%{year: nil, location: location, month: month}) do
    "#{location.name_en} #{Timex.month_name(month)} List"
  end

  defp lifelist_title(%{year: year, location: location, month: nil}) do
    "#{year} #{location.name_en} List"
  end

  defp lifelist_title(%{year: year, location: location, month: month}) do
    "#{Timex.month_name(month)} #{year} #{location.name_en} List"
  end

  # Logged in user
  defp derive_current_path_query(%{assigns: %{current_user: current_user} = assigns} = socket)
       when not is_nil(current_user) do
    query =
      [public_view: assigns.public_view]
      |> Keyword.reject(fn {_, val} -> !val end)

    socket
    |> assign(:current_path_query, query)
  end

  # Guest user
  defp derive_current_path_query(socket) do
    socket
    |> assign(:current_path_query, [])
  end

  defp derive_location_field(%{assigns: assigns} = socket) do
    socket
    |> assign(
      :location_field,
      if assigns.public_view do
        :public_location
      else
        :location
      end
    )
  end

  defp derive_page_header(socket) do
    socket
    |> assign(:page_header, lifelist_title(socket.assigns.filter))
  end

  defp derive_page_title(%{assigns: assigns} = socket) do
    socket
    |> assign(:page_title, assigns[:page_header] || lifelist_title(assigns.filter))
  end

  defp derive_robots(%{assigns: %{month: month}} = socket) when not is_nil(month) do
    socket
    |> assign(:robots, [:noindex])
  end

  defp derive_robots(%{assigns: %{filter: %{year: nil}}} = socket) do
    socket
  end

  defp derive_robots(%{assigns: %{lifelist: []}} = socket) do
    socket
    |> assign(:robots, [:noindex])
  end

  defp derive_robots(socket) do
    socket
  end

  defp derive_public_view(socket, params) do
    is_nil(socket.assigns.current_user) || params["public_view"] == "true"
  end

  defp header_style(%{year: nil, location: nil}) do
    "semibold"
  end

  defp header_style(_assigns) do
    "medium"
  end
end
