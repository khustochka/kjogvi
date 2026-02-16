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

    {
      :ok,
      socket
      |> assign(:lifelist_scope, lifelist_scope)
      |> assign(:all_years, all_years)
      |> assign(:container_class, "max-w-7xl"),
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

    location_context = Kjogvi.Geo.get_lifelist_location_context(filter.location)

    location_siblings =
      location_context.siblings
      |> then(fn siblings ->
        case filter.location do
          nil -> siblings
          loc -> (siblings ++ [loc]) |> Enum.sort_by(& &1.public_index)
        end
      end)
      |> Enum.map(fn loc ->
        {loc, loc.id in active_location_ids, loc.id == (filter.location && filter.location.id)}
      end)

    location_children =
      location_context.children
      |> Enum.map(fn loc -> {loc, loc.id in active_location_ids} end)

    {
      :noreply,
      socket
      |> assign(
        lifelist: lifelist,
        filter: filter,
        years: years,
        months: months,
        location_ancestors: location_context.ancestors,
        location_siblings: location_siblings,
        location_children: location_children
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
    <%!-- Page title + stats --%>
    <div class="flex flex-wrap items-end justify-between gap-4 mb-4">
      <.h1 class={["!mb-0", header_style(assigns)]}>
        {@page_header}
      </.h1>
      <div class="flex flex-wrap gap-2 mb-1">
        <.species_count_header lifelist={@lifelist} />
      </div>
    </div>

    <%!-- Two-column layout: sidebar + content --%>
    <div class="lg:flex lg:gap-6">
      <%!-- Sidebar: collapses on mobile, sticky on desktop --%>
      <aside class="lg:w-56 xl:w-64 shrink-0 mb-4 lg:mb-0">
        <div class="sidebar-sticky">
          <%!-- Mobile: toggle button with filter summary --%>
          <button
            phx-click={JS.toggle_class("open", to: "#filter-body")}
            class="lg:hidden w-full flex items-center justify-between gap-3 px-4 py-3 bg-stone-50 border border-stone-200 rounded-lg text-sm text-stone-600 no-underline"
          >
            <span class="flex items-center gap-2 font-medium">
              <.icon name="hero-funnel" class="w-4 h-4" /> Filters
            </span>
            <span class="flex-1 flex flex-wrap justify-end gap-x-1">
              <.filter_summary filter={@filter} />
            </span>
            <.icon name="hero-chevron-down" class="w-4 h-4 text-stone-400 shrink-0" />
          </button>

          <%!-- Filter body: collapsed on mobile, always visible on desktop --%>
          <div id="filter-body" class="filter-body lg:block">
            <div class="mt-2 lg:mt-0 p-4 lg:p-0 bg-white border border-stone-200 lg:border-0 rounded-lg lg:rounded-none space-y-5">
              <%!-- Toggles --%>
              <ul class="space-y-2.5 list-none" aria-label="Filters">
                <li>
                  <.toggle_switch
                    enabled={@filter.exclude_heard_only}
                    href={
                      lifelist_path(
                        @current_scope,
                        %{@filter | exclude_heard_only: !@filter.exclude_heard_only}
                      )
                    }
                    off_label="Exclude heard only"
                    on_label="Heard only excluded"
                    on_action="Include"
                  />
                </li>
                <li>
                  <.toggle_switch
                    enabled={@filter.motorless}
                    href={lifelist_path(@current_scope, %{@filter | motorless: !@filter.motorless})}
                    off_label="Motorless only"
                    on_label="Motorless only"
                    on_action="Include motorized"
                  />
                </li>
              </ul>

              <hr class="border-stone-100" />

              <%!-- Location --%>
              <div id="lifelist-location-selector">
                <div class="filter-label">Location</div>
                <div class="flex flex-wrap items-center gap-1 text-[0.8125rem] mb-2 pl-[5px]">
                  <.link
                    :if={@filter.location != nil}
                    patch={lifelist_path(@current_scope, %{@filter | location: nil})}
                    class="text-forest-600 hover:underline"
                  >
                    World
                  </.link>
                  <span :if={@filter.location == nil} class="font-bold text-stone-700">World</span>
                  <span :for={ancestor <- @location_ancestors} class="flex items-center gap-1">
                    <span class="text-stone-300">&rsaquo;</span>
                    <.link
                      patch={lifelist_path(@current_scope, %{@filter | location: ancestor})}
                      class="text-forest-600 hover:underline"
                    >
                      {ancestor.name_en}
                    </.link>
                  </span>
                </div>
                <ul class="flex flex-wrap gap-1">
                  <.sidebar_location_pill
                    :for={{location, active, selected} <- @location_siblings}
                    selected={selected}
                    active={active}
                    href={lifelist_path(@current_scope, %{@filter | location: location})}
                  >
                    {location.name_en}
                  </.sidebar_location_pill>
                </ul>
                <div :if={@location_children != []}>
                  <hr class="border-stone-100 my-2" />
                  <ul class="flex flex-wrap gap-1">
                    <.sidebar_location_pill
                      :for={{location, active} <- @location_children}
                      selected={false}
                      active={active}
                      href={lifelist_path(@current_scope, %{@filter | location: location})}
                    >
                      {location.name_en}
                    </.sidebar_location_pill>
                  </ul>
                </div>
              </div>

              <hr class="border-stone-100" />

              <%!-- Year --%>
              <div>
                <div class="filter-label">Year</div>
                <ul
                  id="lifelist-year-selector"
                  aria-label="Year"
                  class="sidebar-pill-grid years"
                >
                  <.sidebar_filter_pill
                    selected={is_nil(@filter.year)}
                    class="col-span-full"
                    href={lifelist_path(@current_scope, %{@filter | year: nil})}
                  >
                    All years
                  </.sidebar_filter_pill>
                  <.sidebar_filter_pill
                    :for={{year, active} <- @years}
                    selected={@filter.year == year}
                    active={active}
                    href={lifelist_path(@current_scope, %{@filter | year: year})}
                  >
                    {year}
                  </.sidebar_filter_pill>
                </ul>
              </div>

              <hr class="border-stone-100" />

              <%!-- Month --%>
              <div>
                <div class="filter-label">Month</div>
                <ul
                  id="lifelist-month-selector"
                  aria-label="Month"
                  class="sidebar-pill-grid months"
                >
                  <.sidebar_filter_pill
                    selected={is_nil(@filter.month)}
                    class="col-span-full"
                    href={lifelist_path(@current_scope, %{@filter | month: nil})}
                  >
                    All months
                  </.sidebar_filter_pill>
                  <.sidebar_filter_pill
                    :for={{month, active} <- @months}
                    selected={@filter.month == month}
                    active={active}
                    href={lifelist_path(@current_scope, %{@filter | month: month})}
                  >
                    {DateHelper.short_month_name(month)}
                  </.sidebar_filter_pill>
                </ul>
              </div>
            </div>
          </div>
        </div>
      </aside>

      <%!-- Main content --%>
      <div class="flex-1 min-w-0">
        <div class="mb-8">
          <.lifers_list
            id="lifelist-table"
            show_private_details={@current_scope.private_view}
            lifelist={@lifelist}
            location_field={@location_field}
          />
        </div>

        <%= if @filter.exclude_heard_only and length(@lifelist.extras.heard_only.list) > 0 do %>
          <.h3 id="heard-only-list" class="md:mb-2! text-purple-400!">
            Heard only
          </.h3>

          <.lifers_list
            id="lifelist-heard-only-table"
            show_private_details={@current_scope.private_view}
            lifelist={@lifelist.extras.heard_only}
            location_field={@location_field}
          />
        <% end %>

        <.link_to_top />
      </div>
    </div>
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

  defp header_style(%{filter: %{year: nil, location: nil}}) do
    ""
  end

  defp header_style(_assigns) do
    "!font-medium"
  end

  defp filter_summary(assigns) do
    parts =
      []
      |> then(fn parts ->
        if assigns.filter.location,
          do: parts ++ [assigns.filter.location.name_en],
          else: parts
      end)
      |> then(fn parts ->
        case {assigns.filter.month, assigns.filter.year} do
          {month, year} when not is_nil(month) and not is_nil(year) ->
            parts ++ ["#{DateHelper.short_month_name(month)} #{year}"]

          {nil, year} when not is_nil(year) ->
            parts ++ [to_string(year)]

          {month, nil} when not is_nil(month) ->
            parts ++ [DateHelper.short_month_name(month)]

          _ ->
            parts
        end
      end)
      |> then(fn parts ->
        if assigns.filter.exclude_heard_only,
          do: parts ++ ["Heard only excluded"],
          else: parts
      end)
      |> then(fn parts ->
        if assigns.filter.motorless,
          do: parts ++ ["Motorless only"],
          else: parts
      end)

    assigns = assign(assigns, :parts, parts)

    ~H"""
    <span :for={part <- @parts} class="whitespace-nowrap">
      <span class="font-semibold text-stone-700">{part}</span>
      <span :if={part != List.last(@parts)} class="text-stone-400 mx-0.5">&middot;</span>
    </span>
    """
  end

  defp species_count_header(%{lifelist: %{filter: %{exclude_heard_only: false}}} = assigns) do
    ~H"""
    <div class="inline-flex items-baseline gap-2.5 bg-forest-600 text-white px-4 py-2.5 rounded-lg">
      <span class="text-2xl font-header font-bold tracking-tight">{@lifelist.total}</span>
      <span class="text-forest-100 text-sm font-medium">species recorded</span>
    </div>
    """
  end

  defp species_count_header(%{lifelist: %{extras: %{heard_only: %{list: []}}}} = assigns) do
    ~H"""
    <div class="inline-flex items-baseline gap-2.5 bg-forest-600 text-white px-4 py-2.5 rounded-lg">
      <span class="text-2xl font-header font-bold tracking-tight">{@lifelist.total}</span>
      <span class="text-forest-100 text-sm font-medium">species seen</span>
    </div>
    <div class="inline-flex items-baseline gap-2.5 bg-purple-600/60 text-white px-4 py-2.5 rounded-lg">
      <span class="text-2xl font-header font-bold tracking-tight">&nbsp;</span>
      <span class="text-purple-100 text-sm font-medium">No heard only species</span>
    </div>
    """
  end

  defp species_count_header(%{lifelist: %{filter: %{exclude_heard_only: true}}} = assigns) do
    ~H"""
    <div class="inline-flex items-baseline gap-2.5 bg-forest-600 text-white px-4 py-2.5 rounded-lg">
      <span class="text-2xl font-header font-bold tracking-tight">{@lifelist.total}</span>
      <span class="text-forest-100 text-sm font-medium">species seen</span>
    </div>
    <a
      href="#heard-only-list"
      class="inline-flex items-baseline gap-2.5 bg-purple-600 text-white px-4 py-2.5 rounded-lg hover:bg-purple-700 no-underline group"
    >
      <span class="text-2xl font-header font-bold tracking-tight">
        {length(@lifelist.extras.heard_only.list)}
      </span>
      <span class="text-purple-100 text-sm font-medium group-hover:underline">heard only ↓</span>
    </a>
    """
  end
end
