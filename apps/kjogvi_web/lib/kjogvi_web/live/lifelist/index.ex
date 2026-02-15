defmodule KjogviWeb.Live.Lifelist.Index do
  @moduledoc false

  use KjogviWeb, :live_view

  alias Kjogvi.Util
  alias Kjogvi.Birding
  alias Kjogvi.Birding.Lifelist

  alias KjogviWeb.DateHelper
  alias KjogviWeb.Live.Lifelist.Presenter

  import KjogviWeb.Live.Lifelist.Components

  @all_months 1..12

  @impl true
  def mount(_params, _session, %{assigns: assigns} = socket) do
    lifelist_scope = Lifelist.Scope.from_scope(assigns.current_scope)
    all_years = Birding.Lifelist.years(lifelist_scope)
    all_locations = Kjogvi.Geo.get_lifelist_locations()

    {
      :ok,
      socket
      |> assign(:lifelist_scope, lifelist_scope)
      |> assign(:all_years, all_years)
      |> assign(:all_locations, all_locations),
      temporary_assigns: [lifelist: []]
    }
  end

  @impl true
  def handle_params(params, _url, %{assigns: assigns} = socket) do
    lifelist_scope = assigns.lifelist_scope

    filter = build_filter(assigns.current_scope, params)

    lifelist = Birding.Lifelist.generate(lifelist_scope, filter)

    years =
      Birding.Lifelist.years(lifelist_scope, Map.put(filter, :year, nil))
      |> then(&Util.Enum.zip_inclusion(assigns.all_years, &1))

    months =
      Birding.Lifelist.months(lifelist_scope, Map.put(filter, :month, nil))
      |> then(&Util.Enum.zip_inclusion(@all_months, &1))

    active_location_ids =
      Birding.Lifelist.location_ids(lifelist_scope, Map.put(filter, :location, nil))

    locations =
      assigns.all_locations
      |> Enum.map(fn el -> {el, el.id in active_location_ids} end)

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

    <div class="my-6">
      <div class="mb-1 text-sm font-semibold leading-6 text-zinc-600">
        Location:
      </div>
      <ul
        id="lifelist-location-selector"
        class="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-6 gap-1"
      >
        <.filter_pill
          selected={is_nil(@filter.location)}
          class="col-span-full lg:col-span-1 justify-self-start lg:justify-self-stretch"
          href={lifelist_path(@current_scope, %{@filter | location: nil})}
        >
          World
        </.filter_pill>
        <.filter_pill
          :for={{location, active} <- @locations}
          selected={@filter.location == location}
          active={active}
          href={lifelist_path(@current_scope, %{@filter | location: location})}
        >
          {location.name_en}
        </.filter_pill>
      </ul>
    </div>

    <div class="my-6">
      <div class="mb-1 text-sm font-semibold leading-6 text-zinc-600">
        Year:
      </div>
      <ul
        id="lifelist-year-selector"
        class="grid grid-cols-4 sm:grid-cols-6 lg:grid-cols-10 gap-1"
      >
        <.filter_pill
          selected={is_nil(@filter.year)}
          class="col-span-full lg:col-span-1 justify-self-start lg:justify-self-stretch"
          href={lifelist_path(@current_scope, %{@filter | year: nil})}
        >
          All years
        </.filter_pill>
        <.filter_pill
          :for={{year, active} <- @years}
          selected={@filter.year == year}
          active={active}
          href={lifelist_path(@current_scope, %{@filter | year: year})}
        >
          {year}
        </.filter_pill>
      </ul>
    </div>

    <div class="my-6">
      <div class="mb-1 text-sm font-semibold leading-6 text-zinc-600">
        Month:
      </div>
      <ul
        id="lifelist-month-selector"
        class="grid grid-cols-4 sm:grid-cols-6 lg:grid-cols-[auto_repeat(12,minmax(0,1fr))] gap-1"
      >
        <.filter_pill
          selected={is_nil(@filter.month)}
          class="col-span-full lg:col-span-1 justify-self-start lg:justify-self-stretch"
          href={lifelist_path(@current_scope, %{@filter | month: nil})}
        >
          All months
        </.filter_pill>
        <.filter_pill
          :for={{month, active} <- @months}
          selected={@filter.month == month}
          active={active}
          href={lifelist_path(@current_scope, %{@filter | month: month})}
        >
          {DateHelper.short_month_name(month)}
        </.filter_pill>
      </ul>
    </div>

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
      <.h3 id="heard-only-list" class="md:mb-2!">
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
