defmodule KjogviWeb.Live.Lifelist.Index do
  @moduledoc false

  alias Kjogvi.Birding.Lifelist
  use KjogviWeb, :live_view

  alias Kjogvi.Util
  alias Kjogvi.Birding

  alias KjogviWeb.Live.Lifelist.Presenter

  import KjogviWeb.Live.Lifelist.Components

  @all_months 1..12

  @impl true
  def mount(_params, _session, %{assigns: assigns} = socket) do
    {
      :ok,
      socket
      |> assign(:lifelist_scope, Lifelist.Scope.from_scope(assigns.current_scope))
    }
  end

  @impl true
  def handle_params(params, _url, %{assigns: assigns} = socket) do
    lifelist_scope = assigns.lifelist_scope

    filter = build_filter(assigns.current_scope, params)

    lifelist = Birding.Lifelist.generate(lifelist_scope, filter)

    all_years = Birding.Lifelist.years(lifelist_scope)

    years =
      Birding.Lifelist.years(lifelist_scope, Map.put(filter, :year, nil))
      |> then(&Util.Enum.zip_inclusion(all_years, &1))

    months =
      Birding.Lifelist.months(lifelist_scope, Map.put(filter, :month, nil))
      |> then(&Util.Enum.zip_inclusion(@all_months, &1))

    all_countries = Kjogvi.Geo.get_countries()
    country_ids = Birding.Lifelist.country_ids(lifelist_scope, Map.put(filter, :location, nil))

    locations =
      all_countries
      |> Enum.map(fn el -> {el, el.id in country_ids} end)

    {
      :noreply,
      socket
      |> assign(
        lifelist: lifelist,
        filter: filter,
        years: years,
        months: months,
        locations: locations
      )
      |> derive_location_field()
      |> derive_page_header()
      |> derive_page_title()
      |> derive_robots()
    }
  end

  @impl true
  @spec render(any()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <.header_with_subheader class={header_style(assigns)}>
      {@page_header}
      <:subheader>
        <%= if @filter.motorless do %>
          Motorless
        <% else %>
          &nbsp;
        <% end %>
        <%= if @filter.exclude_heard_only do %>
          &bull; Heard only <a href="#heard-only-list">separated</a>
        <% else %>
          &nbsp;
        <% end %>
      </:subheader>
    </.header_with_subheader>

    <ul class="flex flex-wrap gap-x-4 gap-y-2 mt-4">
      <li class="whitespace-nowrap">
        <em :if={!@filter.exclude_heard_only} class="font-semibold not-italic">Include all</em>
        <.link
          :if={@filter.exclude_heard_only}
          patch={lifelist_path(@current_scope, %{@filter | exclude_heard_only: false})}
        >
          Include all
        </.link>
      </li>
      <li class="whitespace-nowrap">
        <em :if={@filter.exclude_heard_only} class="font-semibold not-italic">Separate heard only</em>
        <.link
          :if={!@filter.exclude_heard_only}
          patch={lifelist_path(@current_scope, %{@filter | exclude_heard_only: true})}
        >
          Separate heard only
        </.link>
      </li>
    </ul>

    <ul class="flex flex-wrap gap-x-4 gap-y-2 mt-4">
      <li class="whitespace-nowrap">
        <em :if={!@filter.motorless} class="font-semibold not-italic">Include all</em>
        <.link
          :if={@filter.motorless}
          patch={lifelist_path(@current_scope, %{@filter | motorless: false})}
        >
          Include all
        </.link>
      </li>
      <li class="whitespace-nowrap">
        <em :if={@filter.motorless} class="font-semibold not-italic">Motorless only</em>
        <.link
          :if={!@filter.motorless}
          patch={lifelist_path(@current_scope, %{@filter | motorless: true})}
        >
          Motorless only
        </.link>
      </li>
    </ul>

    <div class="w-full md:flex md:gap-6">
      <div class="my-6 md:w-1/3">
        <div class="mb-1 text-sm font-semibold leading-6 text-zinc-600">
          Year:
        </div>
        <.bivalve_select
          selected={@filter.year}
          id="lifelist-year-selector"
          widths="w-1/2 sm:w-1/4 md:w-1/4 lg:w-1/4 xl:w-1/4"
          selector_widths="w-1/2 sm:w-1/4 md:w-1/2"
        >
          <:left href={lifelist_path(@current_scope, %{@filter | year: nil})}>
            All years
          </:left>
          <:placeholder>
            <%= if is_nil(@filter.year) do %>
              Select
            <% else %>
              <span class="sr-only">Selected year:</span>
              {@filter.year}
            <% end %>
          </:placeholder>
          <:item
            :for={{year, active} <- @years}
            key={year}
            active={active}
            href={lifelist_path(@current_scope, %{@filter | year: year})}
          >
            {year}
          </:item>
        </.bivalve_select>
      </div>

      <div class="my-6 md:w-1/3">
        <div class="mb-1 text-sm font-semibold leading-6 text-zinc-600">
          Month:
        </div>
        <.bivalve_select
          selected={@filter.month}
          id="lifelist-month-selector"
          widths="w-1/4 sm:w-1/4 lg:w-1/6"
          selector_widths="w-1/2 sm:w-1/4 md:w-1/2"
        >
          <:left href={lifelist_path(@current_scope, %{@filter | month: nil})}>
            All months
          </:left>
          <:placeholder>
            <%= if is_nil(@filter.month) do %>
              Select
            <% else %>
              <span class="sr-only">Selected month:</span>
              {Timex.month_name(@filter.month)}
            <% end %>
          </:placeholder>
          <:item
            :for={{month, active} <- @months}
            key={month}
            active={active}
            href={lifelist_path(@current_scope, %{@filter | month: month})}
          >
            {Timex.month_shortname(month)}
          </:item>
        </.bivalve_select>
      </div>
    </div>

    <ul class="flex flex-wrap gap-x-4 gap-y-2 my-8">
      <li class="whitespace-nowrap">
        <em :if={is_nil(@filter.location)} class="font-semibold not-italic">All countries</em>
        <.link
          :if={not is_nil(@filter.location)}
          patch={lifelist_path(@current_scope, %{@filter | location: nil})}
        >
          All countries
        </.link>
      </li>
      <%= for {location, active} <- @locations do %>
        <li>
          <%= if @filter.location == location do %>
            <em class="font-semibold not-italic">{location.name_en}</em>
          <% else %>
            <%= if active do %>
              <.link patch={lifelist_path(@current_scope, %{@filter | location: location})}>
                {location.name_en}
              </.link>
            <% else %>
              <span class="text-gray-500">{location.name_en}</span>
            <% end %>
          <% end %>
        </li>
      <% end %>
    </ul>

    <div class="sm:flex sm:gap-4 my-4">
      <.species_count_header lifelist={@lifelist} />
    </div>

    <div class="mb-8">
      <.lifers_list
        id="lifelist-table"
        show_private_details={@current_scope.private_view}
        lifelist={@lifelist}
        location_field={@location_field}
      />
    </div>

    <%= if @filter.exclude_heard_only do %>
      <.h3 id="heard-only-list" class="md:!mb-2">
        Heard only
      </.h3>

      <%= if length(@lifelist.extras.heard_only.list) > 0 do %>
        <.lifers_list
          id="lifelist-heard-only-table"
          show_private_details={@current_scope.private_view}
          lifelist={@lifelist.extras.heard_only}
          location_field={@location_field}
        />
      <% else %>
        <p>No heard only birds</p>
      <% end %>
    <% end %>

    <.link_to_top />
    """
  end

  defp build_filter(scope, params) do
    KjogviWeb.Live.Lifelist.Params.to_filter(scope, params)
    |> case do
      {:ok, filter} -> filter
      {:error, _} -> raise Plug.BadRequestError
    end
  end

  defp derive_location_field(%{assigns: assigns} = socket) do
    socket
    |> assign(
      :location_field,
      if assigns.current_scope.private_view do
        :location
      else
        :public_location
      end
    )
  end

  defp derive_page_header(socket) do
    socket
    |> assign(:page_header, Presenter.title(socket.assigns.filter))
  end

  defp derive_page_title(%{assigns: assigns} = socket) do
    socket
    |> assign(:page_title, assigns[:page_header] || Presenter.title(assigns.filter))
  end

  # Private view not indexed
  defp derive_robots(%{assigns: %{current_scope: %{private_view: true}}} = socket) do
    socket
    |> assign(:robots, [:noindex])
  end

  # Empty list is not indexed
  defp derive_robots(%{assigns: %{lifelist: %{list: []}}} = socket) do
    socket
    |> assign(:robots, [:noindex])
  end

  defp derive_robots(%{assigns: assigns} = socket) do
    socket
    |> assign(:robots, Presenter.robots(assigns.filter))
  end

  defp header_style(%{year: nil, location: nil}) do
    ""
  end

  defp header_style(_assigns) do
    "!font-medium"
  end

  defp species_count_header(%{lifelist: %{filter: %{exclude_heard_only: false}}} = assigns) do
    ~H"""
    <div class="sm:w-full p-4 my-2 bg-emerald-100 text-emerald-700 rounded">
      <span class="text-2xl font-bold">{@lifelist.total}</span> species recorded.
    </div>
    """
  end

  defp species_count_header(%{lifelist: %{extras: %{heard_only: %{list: []}}}} = assigns) do
    ~H"""
    <div class="sm:w-1/2 p-4 my-2 bg-emerald-100 text-emerald-700 rounded">
      <span class="text-2xl font-bold">{@lifelist.total}</span> species seen.
    </div>
    <div class="sm:w-1/2 p-4 my-2 bg-purple-100 text-purple-700 rounded">
      No heard only species.
    </div>
    """
  end

  defp species_count_header(%{lifelist: %{filter: %{exclude_heard_only: true}}} = assigns) do
    ~H"""
    <div class="sm:w-1/2 p-4 my-2 bg-emerald-100 text-emerald-700 rounded">
      <span class="text-2xl font-bold">{@lifelist.total}</span> species seen.
    </div>
    <div class="sm:w-1/2 p-4 my-2 bg-purple-100 text-purple-800 rounded">
      <a href="#heard-only-list"><span class="text-2xl font-bold">{length(@lifelist.extras.heard_only.list)}</span> species heard only</a>.
    </div>
    """
  end
end
