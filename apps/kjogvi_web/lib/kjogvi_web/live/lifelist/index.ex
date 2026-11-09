defmodule KjogviWeb.Live.Lifelist.Index do
  @moduledoc """
  The lifelist, filtered by location, year, month, etc.

  Serves the community, user, and private species lifelists, plus the `:taxa`
  action: the private lifelist of taxa in a taxonomy book (`?book=slug/version`,
  defaulting to the user's default taxonomy), with taxa that couldn't be matched
  into the book listed above it.
  """

  use KjogviWeb, :live_view

  alias Kjogvi.Util
  alias Kjogvi.Birding.Lifelist

  alias KjogviWeb.DateHelper
  alias KjogviWeb.Live.Lifelist.Grouping
  alias KjogviWeb.Live.Lifelist.Presenter

  import KjogviWeb.Live.Lifelist.Components

  @all_months 1..12

  @toggle_labels [
    exclude_heard_only: "Heard only excluded",
    motorless: "Motorless only"
  ]

  @impl true
  def mount(_params, _session, %{assigns: %{live_action: :taxa_redirect}} = socket) do
    {:ok, push_navigate(socket, to: ~p"/my/taxa/lifelist")}
  end

  def mount(_params, _session, %{assigns: %{live_action: :taxa} = assigns} = socket) do
    socket
    |> assign(:default_book, Kjogvi.Accounts.default_book(assigns.current_scope.current_user))
    |> assign(:books, Ornitho.Finder.Book.all())
    |> mount_lifelist()
  end

  def mount(_params, _session, socket) do
    mount_lifelist(socket)
  end

  defp mount_lifelist(socket) do
    {
      :ok,
      assign(socket, :container_class, "max-w-7xl"),
      temporary_assigns: [lifelist: nil, lifer_groups: nil, heard_only_groups: nil]
    }
  end

  @impl true
  def handle_params(params, _url, %{assigns: %{live_action: :taxa} = assigns} = socket) do
    {signature, params} = Map.pop(params, "book")

    case taxa_book(signature, assigns.default_book) do
      nil ->
        {:noreply, assign(socket, book: nil, page_title: "Taxa Lifelist", robots: [:noindex])}

      book ->
        socket |> assign(:book, book) |> handle_lifelist_params(params)
    end
  end

  def handle_params(params, _url, socket) do
    socket |> assign(:book, nil) |> handle_lifelist_params(params)
  end

  @impl true
  def handle_event("select_book", %{"book" => signature}, %{assigns: assigns} = socket) do
    book = Enum.find(assigns.books, &(book_signature(&1) == signature)) || assigns.book

    {:noreply,
     push_patch(socket, to: lifelist_path(assigns.current_scope, %{assigns.filter | book: book}))}
  end

  defp taxa_book(nil, default_book), do: default_book

  defp taxa_book(signature, _default_book) do
    with [slug, version] <- String.split(signature, "/"),
         %Ornitho.Schema.Book{} = book <- Ornitho.Finder.Book.by_signature(slug, version) do
      book
    else
      _ -> raise KjogviWeb.NotFoundError
    end
  end

  defp book_signature(book), do: "#{book.slug}/#{book.version}"

  defp handle_lifelist_params(%{assigns: assigns} = socket, params) do
    scope = assigns.current_scope

    # Book lifelists cover every observation, so the book doesn't change the years.
    socket =
      assign_new(socket, :all_years, fn ->
        Lifelist.years(scope, book: assigns.book) |> Enum.reverse()
      end)

    assigns = socket.assigns

    filter =
      KjogviWeb.Live.Lifelist.Params.to_filter(scope, params)
      |> case do
        {:ok, filter} -> with_book(filter, assigns.book)
        {:error, _} -> raise KjogviWeb.NotFoundError
      end

    lifelist = Lifelist.generate(scope, filter)

    years =
      Lifelist.years(scope, Map.put(filter, :year, nil))
      |> Enum.reverse()
      |> then(&Util.Enum.zip_inclusion(assigns.all_years, &1))

    months =
      Lifelist.months(scope, Map.put(filter, :month, nil))
      |> then(&Util.Enum.zip_inclusion(@all_months, &1))

    # Which locations to show as pills: countries/subdivisions with observations
    # across the whole lifelist (ignoring the current filter).
    present_locations =
      Kjogvi.Geo.get_locations_by_ids(Lifelist.location_ids(scope, book: assigns.book))

    # Which of those pills are active: locations with observations within the
    # current filtered subset.
    active_location_ids =
      Lifelist.location_ids(scope, Map.put(filter, :location, nil))
      |> MapSet.new()

    location_context =
      Kjogvi.Geo.get_lifelist_location_context(present_locations, filter.location)

    location_siblings =
      location_context.siblings
      |> then(fn siblings ->
        case filter.location do
          nil -> siblings
          loc -> (siblings ++ [loc]) |> Enum.sort_by(& &1.name_en)
        end
      end)
      |> Enum.map(fn loc ->
        {loc, MapSet.member?(active_location_ids, loc.id),
         loc.id == (filter.location && filter.location.id)}
      end)

    location_children =
      location_context.children
      |> Enum.map(fn loc -> {loc, MapSet.member?(active_location_ids, loc.id)} end)

    lifer_groups = group_lifelist(lifelist)

    heard_only_groups =
      if heard_only = get_in(lifelist.extras, [:heard_only]),
        do: group_lifelist(heard_only),
        else: []

    {
      :noreply,
      socket
      |> assign(
        lifelist: lifelist,
        lifer_groups: lifer_groups,
        heard_only_groups: heard_only_groups,
        filter: filter,
        years: years,
        months: months,
        location_ancestors: location_context.ancestors,
        location_siblings: location_siblings,
        location_children: location_children,
        location_ancestor_segments: location_ancestor_segments(scope, filter.location)
      )
      |> derive_page_header()
      |> derive_page_title()
      |> derive_robots()
    }
  end

  defp with_book(filter, nil), do: filter

  # The taxa lifelist has no motorless or heard-only filters.
  defp with_book(filter, book),
    do: %{filter | book: book, motorless: false, exclude_heard_only: false}

  defp group_lifelist(%{filter: %{sort: :taxonomy}} = lifelist),
    do: Grouping.by_taxonomy(lifelist)

  defp group_lifelist(lifelist), do: Grouping.by_year(lifelist)

  @impl true
  @spec render(any()) :: Phoenix.LiveView.Rendered.t()
  def render(%{live_action: :taxa, book: nil} = assigns) do
    ~H"""
    <.h1>{@page_title}</.h1>
    <div
      id="taxa-no-default-book"
      class="my-6 p-4 rounded border border-amber-300 bg-amber-50 text-sm text-stone-700"
    >
      You have no default taxonomy, so there is nothing to show. See <.link
        navigate={~p"/my/settings/preferences#default-taxonomy"}
        class="text-forest-700 underline hover:text-forest-900"
      >Preferences</.link>.
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <%!-- Page title + stats --%>
    <div class="flex flex-wrap items-end justify-between gap-4 mb-4">
      <div>
        <.h1 class="mb-0!">
          {@page_header}
        </.h1>
        <p
          :if={@location_ancestor_segments != []}
          id="lifelist-location-subheader"
          class="mt-1 text-stone-500"
          phx-no-format
        ><%= for {segment, index} <- Enum.with_index(@location_ancestor_segments) do %><span :if={index > 0}>, </span><.link href={lifelist_path(@current_scope, %{@filter | location: segment})} class="decoration-stone-300 hover:text-stone-700 hover:decoration-stone-500">{segment.name_en}</.link><% end %></p>
        <.book_selector
          :if={@book}
          book={@book}
          books={@books}
          filter={@filter}
          current_scope={@current_scope}
        />
        <ul
          :if={@filter.motorless or @filter.exclude_heard_only}
          class="mt-2 flex flex-wrap items-center gap-2 list-none"
          aria-label="Active filters"
        >
          <.filter_badge
            :if={@filter.motorless}
            label="Motorless only"
            href={lifelist_path(@current_scope, %{@filter | motorless: false})}
          />
          <.filter_badge
            :if={@filter.exclude_heard_only}
            label="Heard only excluded"
            href={lifelist_path(@current_scope, %{@filter | exclude_heard_only: false})}
          />
        </ul>
      </div>
      <div class="flex flex-wrap gap-2 mb-1">
        <.species_count_header
          lifelist={@lifelist}
          unit={count_unit(@filter)}
          current_scope={@current_scope}
        />
      </div>
    </div>

    <%!-- Two-column layout: sidebar + content --%>
    <div class="lg:flex lg:gap-6">
      <%!-- Sidebar: collapses on mobile, sticky on desktop --%>
      <aside class="lg:w-56 xl:w-64 shrink-0 mb-4 lg:mb-0">
        <div class="sidebar-sticky">
          <%!-- Outside the collapsible filters: it changes what is listed, not which records --%>
          <div
            :if={@book}
            id="lifelist-species-only"
            class="mb-3 lg:mb-5 lg:pb-5 lg:border-b lg:border-stone-100"
          >
            <.toggle_switch
              enabled={@filter.species_only}
              href={lifelist_path(@current_scope, %{@filter | species_only: !@filter.species_only})}
              off_label="Species only"
              on_label="Species only"
              on_action="Include all taxa"
            />
          </div>

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
              <%!-- Location --%>
              <div id="lifelist-location-selector">
                <div class="filter-label">Location</div>
                <ul
                  :if={@location_ancestors != []}
                  class="flex flex-wrap items-center gap-1.5 lg:gap-1 pb-2 mb-2 border-b border-stone-100"
                >
                  <.inline_filter_pill href={
                    lifelist_path(@current_scope, %{@filter | location: nil})
                  }>
                    World
                  </.inline_filter_pill>
                  <li :for={ancestor <- @location_ancestors} class="flex items-center gap-1">
                    <span class="text-stone-300">&rsaquo;</span>
                    <.inline_filter_pill href={
                      lifelist_path(@current_scope, %{@filter | location: ancestor})
                    }>
                      {ancestor.name_en}
                    </.inline_filter_pill>
                  </li>
                </ul>
                <ul class="flex flex-wrap gap-1.5 lg:gap-1">
                  <.inline_filter_pill
                    :if={@location_ancestors == []}
                    selected={@filter.location == nil}
                    href={lifelist_path(@current_scope, %{@filter | location: nil})}
                  >
                    World
                  </.inline_filter_pill>
                  <.inline_filter_pill
                    :for={{location, active, selected} <- @location_siblings}
                    selected={selected}
                    active={active}
                    href={lifelist_path(@current_scope, %{@filter | location: location})}
                  >
                    {location.name_en}
                  </.inline_filter_pill>
                </ul>
                <div :if={@location_children != []}>
                  <hr class="border-stone-100 my-2" />
                  <ul class="flex flex-wrap gap-1.5 lg:gap-1">
                    <.inline_filter_pill
                      :for={{location, active} <- @location_children}
                      selected={false}
                      active={active}
                      href={lifelist_path(@current_scope, %{@filter | location: location})}
                    >
                      {location.name_en}
                    </.inline_filter_pill>
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
                  <.grid_filter_pill
                    selected={is_nil(@filter.year)}
                    class="col-span-full"
                    href={lifelist_path(@current_scope, %{@filter | year: nil})}
                  >
                    All years
                  </.grid_filter_pill>
                  <.grid_filter_pill
                    :for={{year, active} <- @years}
                    selected={@filter.year == year}
                    active={active}
                    href={lifelist_path(@current_scope, %{@filter | year: year})}
                  >
                    {year}
                  </.grid_filter_pill>
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
                  <.grid_filter_pill
                    selected={is_nil(@filter.month)}
                    class="col-span-full"
                    href={lifelist_path(@current_scope, %{@filter | month: nil})}
                  >
                    All months
                  </.grid_filter_pill>
                  <.grid_filter_pill
                    :for={{month, active} <- @months}
                    selected={@filter.month == month}
                    active={active}
                    href={lifelist_path(@current_scope, %{@filter | month: month})}
                  >
                    {DateHelper.short_month_name(month)}
                  </.grid_filter_pill>
                </ul>
              </div>

              <hr :if={is_nil(@book)} class="border-stone-100" />

              <%!-- Toggles (lower priority filters) --%>
              <ul :if={is_nil(@book)} class="space-y-3 list-none" aria-label="Filters">
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
            </div>
          </div>
        </div>
      </aside>

      <%!-- Main content --%>
      <div class="flex-1 min-w-0">
        <.unmatched_taxa :if={@book} book={@book} entries={@lifelist.extras.unmatched} />
        <.no_species_taxa :if={@book} book={@book} entries={@lifelist.extras.no_species} />

        <div class="mb-3 flex flex-wrap items-center justify-end gap-2">
          <.sort_selector
            current_sort={@filter.sort}
            date_href={lifelist_path(@current_scope, %{@filter | sort: :date})}
            taxonomy_href={lifelist_path(@current_scope, %{@filter | sort: :taxonomy})}
          />
        </div>

        <div class="mb-8">
          <.lifers_list
            id="lifelist-table"
            show_private_details={Kjogvi.Scope.visibility(@current_scope) == :private}
            groups={@lifer_groups}
            sort={@filter.sort}
            relative_to={@filter.location}
          />
        </div>

        <%= if @filter.exclude_heard_only and length(@lifelist.extras.heard_only.list) > 0 do %>
          <.h3 id="heard-only-list" class="md:mb-2! text-stone-600!">
            Heard only
          </.h3>

          <.lifers_list
            id="lifelist-heard-only-table"
            show_private_details={Kjogvi.Scope.visibility(@current_scope) == :private}
            groups={@heard_only_groups}
            sort={@filter.sort}
            anchor_prefix="heard-only-"
            relative_to={@filter.location}
          />
        <% end %>

        <.link_to_top />
      </div>
    </div>
    """
  end

  defp derive_page_header(socket) do
    socket
    |> assign(:page_header, Presenter.title(socket.assigns.filter))
  end

  # Ancestor segments shown as links under the title. The location's own name is
  # dropped (it's already in the title), leaving the remaining ancestry: empty
  # for World (no filter) or a country / location with no visible ancestors, in
  # which case no subheader renders.
  defp location_ancestor_segments(_scope, nil), do: []

  defp location_ancestor_segments(scope, location) do
    location = Kjogvi.Geo.Location.Query.put_levels(location)

    Kjogvi.Geo.Location.name_segments(Kjogvi.Scope.visibility(scope), location)
    |> Enum.drop(1)
  end

  defp derive_page_title(%{assigns: %{book: nil} = assigns} = socket) do
    socket
    |> assign(:page_title, assigns[:page_header] || Presenter.title(assigns.filter))
  end

  defp derive_page_title(%{assigns: assigns} = socket) do
    socket
    |> assign(:page_title, "#{assigns.page_header} (#{assigns.book.name})")
  end

  defp count_unit(%{book: %Ornitho.Schema.Book{}, species_only: false}), do: "taxa"
  defp count_unit(_filter), do: "species"

  # Private view not indexed
  defp derive_robots(%{assigns: %{current_scope: %Kjogvi.Scope{area: area}}} = socket)
       when area in [:private, :admin] do
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
      |> Kernel.++(for {key, label} <- @toggle_labels, Map.fetch!(assigns.filter, key), do: label)

    assigns = assign(assigns, :parts, parts)

    ~H"""
    <span :for={part <- @parts} class="whitespace-nowrap">
      <span class="font-semibold text-stone-700">{part}</span>
      <span :if={part != List.last(@parts)} class="text-stone-400 mx-0.5">&middot;</span>
    </span>
    """
  end

  # Without JS, the form submits as a GET to the current path; the hidden fields
  # carry the other query params, which a GET form would otherwise drop.
  defp book_selector(assigns) do
    {_year, _location, query} = KjogviWeb.Paths.LifelistPath.split_params(assigns.filter)
    assigns = assign(assigns, :query, query)

    ~H"""
    <form
      id="lifelist-book"
      method="get"
      action={lifelist_path(@current_scope, @filter)}
      phx-change="select_book"
      class="mt-2 flex flex-wrap items-center gap-2 text-sm"
    >
      <label for="lifelist-book-select" class="text-stone-600">Taxonomy</label>
      <select
        id="lifelist-book-select"
        name="book"
        class="w-auto pr-8 py-1 rounded-md border border-stone-300 bg-white text-sm text-stone-800 focus:border-stone-400 focus:ring-0"
      >
        <option
          :for={book <- @books}
          value={book_signature(book)}
          selected={book.id == @book.id}
        >
          {book.name}
        </option>
      </select>
      <input :for={{name, value} <- @query} type="hidden" name={name} value={value} />
      <noscript>
        <button type="submit" class="px-2 py-1 rounded-md border border-stone-300">Show</button>
      </noscript>
    </form>
    """
  end

  attr :book, Ornitho.Schema.Book, required: true
  attr :entries, :list, required: true

  # Recorded taxa missing from the list though they should be on it.
  defp unmatched_taxa(%{entries: []} = assigns), do: ~H""

  defp unmatched_taxa(assigns) do
    ~H"""
    <section
      id="taxa-unmatched"
      aria-labelledby="taxa-unmatched-heading"
      class="mb-4 p-4 rounded-lg border border-red-300 bg-red-50 text-sm text-red-900"
    >
      <h2 id="taxa-unmatched-heading" class="font-semibold">
        Not matched in {@book.name}: {length(@entries)}
      </h2>
      <p>These recorded taxa are missing from the list below.</p>
      <ul class="mt-2 space-y-1">
        <li :for={entry <- @entries} id={"taxa-unmatched-#{entry.id}"}>
          <.recorded_taxon entry={entry} />
        </li>
      </ul>
    </section>
    """
  end

  attr :book, Ornitho.Schema.Book, required: true
  attr :entries, :list, required: true

  # Taxa without a species from other books: their absence is expected.
  defp no_species_taxa(%{entries: []} = assigns), do: ~H""

  defp no_species_taxa(assigns) do
    ~H"""
    <details id="taxa-no-species" class="mb-4 text-sm text-stone-600">
      <summary class="cursor-pointer">
        No counterpart in {@book.name}: {length(@entries)} spuhs, slashes, hybrids, etc.
      </summary>
      <ul class="mt-2 ml-4 space-y-1">
        <li :for={entry <- @entries} id={"taxa-no-species-#{entry.id}"}>
          <.recorded_taxon entry={entry} />
        </li>
      </ul>
    </details>
    """
  end

  defp recorded_taxon(%{entry: %{taxon: nil}} = assigns) do
    ~H"""
    Unknown taxon <code class="font-mono">{@entry.taxon_key}</code>
    """
  end

  defp recorded_taxon(assigns) do
    ~H"""
    <.taxon_link taxon={@entry.taxon} />
    <span class="text-xs text-stone-500">
      in {@entry.taxon.book.slug}/{@entry.taxon.book.version}
    </span>
    """
  end

  # All taxa of a book: the taxa count plus the species they roll up to.
  defp species_count_header(
         %{lifelist: %{filter: %{book: %Ornitho.Schema.Book{}, species_only: false}}} = assigns
       ) do
    assigns =
      assign(
        assigns,
        :species_total,
        Kjogvi.Birding.TaxaLifelist.species_count(assigns.lifelist.list)
      )

    ~H"""
    <div
      id="lifelist-total"
      class="inline-flex items-baseline gap-2.5 bg-forest-600 text-white px-4 py-2.5 rounded-lg"
    >
      <span class="text-2xl font-header font-bold tracking-tight">{@lifelist.total}</span>
      <span class="text-forest-100 text-sm font-medium">{@unit} recorded</span>
    </div>
    <.link
      id="lifelist-species-total"
      patch={lifelist_path(@current_scope, %{@lifelist.filter | species_only: true})}
      class="inline-flex items-baseline gap-2.5 bg-forest-100 text-forest-800 px-4 py-2.5 rounded-lg hover:bg-forest-200 no-underline group"
    >
      <span class="text-2xl font-header font-bold tracking-tight">{@species_total}</span>
      <span class="text-sm font-medium group-hover:underline">species recorded</span>
    </.link>
    """
  end

  defp species_count_header(%{lifelist: %{filter: %{exclude_heard_only: false}}} = assigns) do
    ~H"""
    <div
      id="lifelist-total"
      class="inline-flex items-baseline gap-2.5 bg-forest-600 text-white px-4 py-2.5 rounded-lg"
    >
      <span class="text-2xl font-header font-bold tracking-tight">{@lifelist.total}</span>
      <span class="text-forest-100 text-sm font-medium">{@unit} recorded</span>
    </div>
    """
  end

  defp species_count_header(%{lifelist: %{extras: %{heard_only: %{list: []}}}} = assigns) do
    ~H"""
    <div class="inline-flex items-baseline gap-2.5 bg-forest-600 text-white px-4 py-2.5 rounded-lg">
      <span class="text-2xl font-header font-bold tracking-tight">{@lifelist.total}</span>
      <span class="text-forest-100 text-sm font-medium">{@unit} seen</span>
    </div>
    <div class="inline-flex items-baseline gap-2.5 bg-purple-600/60 text-white px-4 py-2.5 rounded-lg">
      <span class="text-2xl font-header font-bold tracking-tight">&nbsp;</span>
      <span class="text-purple-100 text-sm font-medium">No heard only {@unit}</span>
    </div>
    """
  end

  defp species_count_header(%{lifelist: %{filter: %{exclude_heard_only: true}}} = assigns) do
    ~H"""
    <div class="inline-flex items-baseline gap-2.5 bg-forest-600 text-white px-4 py-2.5 rounded-lg">
      <span class="text-2xl font-header font-bold tracking-tight">{@lifelist.total}</span>
      <span class="text-forest-100 text-sm font-medium">{@unit} seen</span>
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
