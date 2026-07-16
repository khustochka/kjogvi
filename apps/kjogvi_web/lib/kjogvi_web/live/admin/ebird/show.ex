defmodule KjogviWeb.Live.Admin.Ebird.Show do
  @moduledoc """
  Matching workbench for one eBird country: the country row, then its
  subdivision1s as a side-by-side eBird-vs-ISO comparison
  (`Kjogvi.Geo.Ebird.subdivision1_comparison/1`) — paired rows on one line,
  each side's leftovers against an empty cell. The manual resolution actions
  (link via autocomplete, unlink, create-from-eBird) act on the eBird side and
  occupy the row's third column, after eBird and ISO; the ISO column is
  read-only context.

  A row the match passes would pair — same ISO code, or matching names — shows
  the ISO location it pairs with, so Link commits that pair outright rather than
  opening the autocomplete to search for what is already on screen. The
  autocomplete remains for rows with nothing to suggest, as does
  create-from-eBird: those are the rows where no location exists to link.

  "Link all matched" (`Kjogvi.Geo.Ebird.match_country/2`) is that same per-row
  Link over every suggested row at once: the passes it runs are the ones the
  comparison previews, so it links what the table proposes and leaves the rest.
  Its counterpart "Create all from eBird" appears only on the
  `:ebird_only_subregions` shape, where ISO has no subdivisions at all and so
  every row can only be created — the one shape where bulk creation cannot
  duplicate a location that should have been linked.

  Countries with eBird subdivision2 regions additionally get the subdivision2
  import (`Kjogvi.Geo.Ebird.import_subdivision2s/1`, run via `start_async` —
  it can create thousands of rows): each subdivision1 comparison row is marked
  with how many of its subdivision2s are imported, and the header button
  creates the rest under their linked subdivision1s.
  """

  use KjogviWeb, :live_view

  alias Kjogvi.Geo
  alias Kjogvi.Geo.EbirdLocation
  alias Kjogvi.Geo.Location
  alias KjogviWeb.Live.Components.LocationAutocomplete

  @impl true
  def mount(%{"country_code" => country_code}, _session, socket) do
    socket =
      socket
      |> assign(:country_code, country_code)
      |> assign(:linking_id, nil)
      |> assign(:importing_sub2, false)
      |> load_country()

    case socket.assigns[:country] do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "eBird country not found")
         |> redirect(to: ~p"/admin/ebird")}

      country ->
        {:ok, assign(socket, :page_title, "eBird: #{country.name}")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("link_all_matched", _params, socket) do
    summary = Geo.Ebird.match_country(socket.assigns.country_code)

    {:noreply,
     socket
     |> put_flash(
       :info,
       "Linked #{summary.code} by code and #{summary.name} by name; #{summary.left} left unmatched."
     )
     |> load_country()}
  end

  def handle_event("import_subdivision2s", _params, socket) do
    country_code = socket.assigns.country_code

    {:noreply,
     socket
     |> clear_flash()
     |> assign(:importing_sub2, true)
     |> start_async(:import_sub2, fn -> Geo.Ebird.import_subdivision2s(country_code) end)}
  end

  def handle_event("create_all", _params, socket) do
    summary = Geo.Ebird.create_all_common_locations(socket.assigns.country_code)

    {:noreply,
     socket
     |> put_flash(:info, create_all_message(summary))
     |> load_country()}
  end

  def handle_event("start_link", %{"id" => id}, socket) do
    {:noreply, assign(socket, :linking_id, String.to_integer(id))}
  end

  def handle_event("link_suggested", %{"id" => id}, socket) do
    ebird_id = String.to_integer(id)
    row = Enum.find(socket.assigns.comparison, &(&1.ebird && &1.ebird.id == ebird_id))

    {:noreply,
     socket
     |> link_region(row.ebird, suggested_location(row))
     |> load_country()}
  end

  def handle_event("cancel_link", _params, socket) do
    {:noreply, assign(socket, :linking_id, nil)}
  end

  def handle_event("unlink", %{"id" => id}, socket) do
    region = find_region(socket, String.to_integer(id))
    {:ok, _} = Geo.Ebird.unlink(region)

    {:noreply,
     socket
     |> put_flash(:info, "Unlinked #{region.code}.")
     |> load_country()}
  end

  def handle_event("create_location", %{"id" => id}, socket) do
    region = find_region(socket, String.to_integer(id))

    socket =
      case Geo.Ebird.create_common_location(region) do
        {:ok, location} ->
          put_flash(socket, :info, "Created #{location.name_en} and linked #{region.code}.")

        {:error, :already_linked} ->
          put_flash(socket, :error, "#{region.code} is already linked.")

        {:error, :country_not_linked} ->
          put_flash(socket, :error, "Link the country row first.")

        {:error, %Ecto.Changeset{}} ->
          put_flash(socket, :error, "Could not create a location: the slug is already taken.")
      end

    {:noreply, load_country(socket)}
  end

  @impl true
  def handle_async(:import_sub2, {:ok, summary}, socket) do
    {:noreply,
     socket
     |> assign(:importing_sub2, false)
     |> put_flash(:info, import_sub2_message(summary))
     |> load_country()}
  end

  def handle_async(:import_sub2, {:exit, reason}, socket) do
    {:noreply,
     socket
     |> assign(:importing_sub2, false)
     |> put_flash(:error, "Subdivision2 import crashed: #{inspect(reason)}")}
  end

  @impl true
  def handle_info({:autocomplete_select, "link_selected", params}, socket) do
    %{"result" => location, "ebird_id" => ebird_id} = params
    region = find_region(socket, ebird_id)

    {:noreply,
     socket
     |> link_region(region, location)
     |> assign(:linking_id, nil)
     |> load_country()}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  defp create_all_message(%{created: created, failed: 0}) do
    "Created and linked #{created} locations."
  end

  defp create_all_message(%{created: created, failed: failed}) do
    "Created and linked #{created} locations; #{failed} could not be created."
  end

  defp import_sub2_message(%{created: created, failed: 0}) do
    "Imported #{created} subdivision2 locations."
  end

  defp import_sub2_message(%{created: created, failed: failed}) do
    "Imported #{created} subdivision2 locations; #{failed} could not be imported " <>
      "(unlinked subdivision1 or a name collision)."
  end

  defp import_sub2_label(true), do: "Importing…"
  defp import_sub2_label(false), do: "Import subdivision2"

  # Links via the autocomplete pick or the suggested-pair button; the outcome
  # reads the same either way.
  defp link_region(socket, region, location) do
    case Geo.Ebird.link(region, location.id) do
      {:ok, _} ->
        put_flash(socket, :info, "Linked #{region.code} to #{location.name_en}.")

      {:error, :already_linked} ->
        put_flash(socket, :error, "#{region.code} is already linked.")

      {:error, :not_common} ->
        put_flash(socket, :error, "Only common locations can be linked.")

      {:error, :not_found} ->
        put_flash(socket, :error, "Location not found.")

      {:error, %Ecto.Changeset{}} ->
        put_flash(
          socket,
          :error,
          "#{location.name_en} is already linked to another eBird region."
        )
    end
  end

  defp load_country(socket) do
    country_code = socket.assigns.country_code
    regions = Geo.Ebird.matchable_locations(country_code)

    socket
    |> assign(:country, Enum.find(regions, &(&1.location_type == :country)))
    |> assign(:regions, regions)
    |> assign(:comparison, Geo.Ebird.subdivision1_comparison(country_code))
    |> assign(:stats, Geo.Ebird.country_status(country_code))
    |> assign(:sub2_by_sub1, Geo.Ebird.sub2_stats_by_sub1(country_code))
  end

  defp find_region(socket, id) do
    Enum.find(socket.assigns.regions, &(&1.id == id))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Breadcrumbs --%>
      <nav id="ebird-breadcrumbs" class="text-sm text-stone-500">
        <.breadcrumb_link href={~p"/admin/ebird"}>eBird Locations</.breadcrumb_link>
        <span class="mx-1 text-stone-400">/</span>
        <span class="text-stone-700">{@country.name}</span>
      </nav>

      <%!-- Header --%>
      <div class="flex flex-wrap items-end justify-between gap-4">
        <div>
          <.h1 class="mb-0!">
            {@country.name}
            <span class="font-mono text-stone-400 text-2xl">{@country.code}</span>
          </.h1>
          <p class="mt-2 flex flex-wrap items-center gap-2 text-sm text-stone-600">
            <.ebird_status_badge status={@stats.status} id="ebird-country-status" />
            <span :if={@stats.sub1_total > 0} id="ebird-sub1-counts">
              {@stats.sub1_linked}/{@stats.sub1_total} subdivisions linked
            </span>
            <span :if={@stats.sub2_total > 0} id="ebird-sub2-counts">
              {@stats.sub2_linked}/{@stats.sub2_total} subdivision2 imported
            </span>
          </p>
        </div>
        <div class="mb-1 flex flex-wrap gap-2">
          <%!-- ISO has no second level, so subdivision2s are only ever created
          from eBird, under their linked subdivision1s. --%>
          <.button
            :if={@stats.sub2_total > @stats.sub2_linked}
            id="import-sub2-button"
            phx-click="import_subdivision2s"
            disabled={@importing_sub2}
            data-confirm={"Create a common location from each of #{@stats.sub2_total - @stats.sub2_linked} unimported eBird subdivision2 regions? Regions whose subdivision1 is not linked are skipped."}
          >
            {import_sub2_label(@importing_sub2)}
          </.button>
          <%!-- ISO has no subdivisions to match against, so creating is the only
          way these rows enter the dataset — offered in bulk on this shape alone. --%>
          <.button
            :if={@stats.status == :ebird_only_subregions and @country.location}
            id="create-all-button"
            phx-click="create_all"
            data-confirm={"Create a common location from each of #{@stats.sub1_total - @stats.sub1_linked} unlinked eBird subdivisions and link them?"}
          >
            Create all from eBird
          </.button>
          <.button
            id="link-all-matched-button"
            phx-click="link_all_matched"
            data-confirm="Link every eBird row that matches a common location by code or name?"
          >
            Link all matched
          </.button>
        </div>
      </div>

      <%!-- The eBird country row --%>
      <div>
        <.h2 class="mb-3!">eBird country</.h2>

        <ul id="ebird-regions" class="border border-stone-200 rounded-lg divide-y divide-stone-100">
          <li id={"ebird-region-#{@country.id}"} class="px-4 py-2.5 space-y-2">
            <div class="flex flex-wrap items-center gap-x-3 gap-y-1">
              <.ebird_cell region={@country} />
              <span class="ml-auto flex flex-wrap gap-2">
                <.region_actions region={@country} country={@country} />
              </span>
            </div>
            <.link_form
              :if={@linking_id == @country.id}
              region={@country}
              country={@country}
              current_scope={@current_scope}
            />
          </li>
        </ul>
      </div>

      <%!-- eBird vs ISO subdivisions, side by side --%>
      <div :if={@comparison != []}>
        <.h2 class="mb-1!">Subdivisions</.h2>
        <p class="mb-3 text-sm text-stone-500">
          eBird's subdivisions beside the common (ISO) ones. A row pairs them when they are
          linked; a blank cell means that side has no counterpart. The ISO column is read-only —
          link from the eBird side.
        </p>

        <ul
          id="sub1-comparison"
          class="border border-stone-200 rounded-lg divide-y divide-stone-100"
        >
          <li :for={row <- @comparison} id={comparison_row_id(row)} class="px-4 py-2.5 space-y-2">
            <%!-- Each row is its own grid, so every track must be content-independent
            for the columns to line up down the table: equal-share sides, a
            fixed-width marker between, and a fixed-width actions column (`auto`
            would collapse on an ISO-only row and shift that row's cells). --%>
            <div class="grid sm:grid-cols-[minmax(0,1fr)_5.5rem_minmax(0,1fr)_11rem] gap-x-3 gap-y-1 items-baseline">
              <%!-- eBird side --%>
              <div class="grid grid-cols-[5.5rem_minmax(0,1fr)] gap-x-2 items-baseline">
                <span :if={row.ebird} class="font-mono text-sm text-stone-500">
                  {row.ebird.code}
                </span>
                <span :if={row.ebird} class="font-medium">{row.ebird.name}</span>
                <.sub2_mark
                  :if={row.ebird}
                  id={"sub2-mark-#{row.ebird.id}"}
                  stats={@sub2_by_sub1[row.ebird.code]}
                />
                <span :if={!row.ebird} class="col-span-2 text-sm text-stone-400">
                  no eBird region
                </span>
              </div>

              <.pairing_marker pairing={row.pairing} />

              <%!-- ISO side --%>
              <div class="grid grid-cols-[5.5rem_minmax(0,1fr)] gap-x-2 items-baseline">
                <span :if={row.location} class="font-mono text-sm text-stone-500">
                  {row.location.iso_code && String.upcase(row.location.iso_code)}
                </span>
                <.link
                  :if={row.location}
                  navigate={~p"/admin/locations/#{row.location.slug}"}
                  class="font-medium text-forest-700"
                  phx-no-format
                >{row.location.name_en}</.link>
                <span :if={!row.location} class="col-span-2 text-sm text-stone-400">
                  no ISO subdivision
                </span>
              </div>

              <div class="flex flex-wrap gap-2">
                <.region_actions
                  :if={row.ebird}
                  region={row.ebird}
                  country={@country}
                  suggested={suggested_location(row)}
                />
              </div>
            </div>

            <.link_form
              :if={row.ebird && @linking_id == row.ebird.id}
              region={row.ebird}
              country={@country}
              current_scope={@current_scope}
            />
          </li>
        </ul>
      </div>
    </div>
    """
  end

  attr :region, EbirdLocation, required: true

  # The country row's code, name and type, plus the common location it links to.
  # Subdivisions don't use this: the comparison's ISO column carries their
  # location instead.
  defp ebird_cell(assigns) do
    ~H"""
    <span class="font-mono text-sm text-stone-500 shrink-0">{@region.code}</span>
    <span class="font-medium">{@region.name}</span>
    <.type_badge type={@region.location_type} />

    <%= if @region.location do %>
      <span class="text-stone-400">&rarr;</span>
      <.link
        navigate={~p"/admin/locations/#{@region.location.slug}"}
        class="text-forest-700"
        phx-no-format
      >{Location.long_name(:private, @region.location)}</.link>
      <span
        :if={!EbirdLocation.code_match?(@region)}
        class="inline-block px-2 py-0.5 text-xs font-medium rounded-full bg-amber-100 text-amber-700"
        title="Linked to a location whose ISO code differs from the eBird code"
      >
        other
      </span>
    <% end %>
    <span :if={!@region.location} class="text-sm text-stone-400">unmatched</span>
    """
  end

  attr :id, :string, required: true

  attr :stats, :map,
    default: nil,
    doc:
      "This subdivision1's sub2 import progress (`%{total: n, linked: n}`); nil renders nothing."

  # Marks a subdivision1 that has eBird subdivision2 regions, with how many are
  # imported. Sits on the second grid line of the eBird cell, under the name.
  defp sub2_mark(assigns) do
    ~H"""
    <span
      :if={@stats}
      id={@id}
      class={[
        "col-start-2 text-xs",
        (@stats.linked == @stats.total && "text-forest-600") || "text-stone-500"
      ]}
      title="eBird subdivision2 regions imported as common locations"
    >
      {@stats.linked}/{@stats.total} sub2 imported
    </span>
    """
  end

  attr :pairing, :atom, required: true

  # The middle column: what ties (or fails to tie) the two sides of a row.
  defp pairing_marker(assigns) do
    ~H"""
    <span class="flex justify-center text-sm">
      <span :if={@pairing == :linked} class="text-forest-600" title="Linked">&rarr;</span>
      <span
        :if={@pairing == :code_suggestion}
        class="text-stone-400"
        title="Same ISO code, not linked yet — Link all matched links this"
      >
        &rarr;
      </span>
      <span
        :if={@pairing == :name_suggestion}
        class="px-2 py-0.5 text-xs font-medium rounded-full bg-amber-100 text-amber-700"
        title="Codes differ but the names match — Link all matched links this"
      >
        by name
      </span>
      <span :if={@pairing in [:ebird_only, :iso_only]} class="text-stone-300" aria-hidden="true">
        &middot;
      </span>
    </span>
    """
  end

  attr :region, EbirdLocation, required: true
  attr :country, EbirdLocation, required: true

  attr :suggested, Location,
    default: nil,
    doc: """
    The ISO location this row pairs with but is not yet linked to. Present, Link
    commits it outright and create-from-eBird is withheld — that location is the
    one the button would duplicate. Absent, Link opens the autocomplete.
    """

  defp region_actions(assigns) do
    ~H"""
    <%= if @region.location do %>
      <button
        type="button"
        phx-click="unlink"
        phx-value-id={@region.id}
        data-confirm={"Unlink #{@region.code} from #{@region.location.name_en}?"}
        class="px-2.5 py-1 text-xs sm:text-sm font-medium text-rose-700 bg-rose-50 hover:bg-rose-100 border border-rose-300 rounded"
      >
        Unlink
      </button>
    <% else %>
      <button
        type="button"
        phx-click={if @suggested, do: "link_suggested", else: "start_link"}
        phx-value-id={@region.id}
        data-confirm={@suggested && "Link #{@region.code} to #{@suggested.name_en}?"}
        class="px-2.5 py-1 text-xs sm:text-sm font-medium text-forest-700 bg-forest-50 hover:bg-forest-100 border border-forest-300 rounded"
      >
        Link
      </button>
      <button
        :if={is_nil(@suggested) and (@region.location_type == :country or @country.location != nil)}
        type="button"
        phx-click="create_location"
        phx-value-id={@region.id}
        data-confirm={"Create a common location from #{@region.code} and link it?"}
        class="px-2.5 py-1 text-xs sm:text-sm font-medium text-stone-700 bg-stone-50 hover:bg-stone-100 border border-stone-300 rounded"
      >
        Create from eBird
      </button>
    <% end %>
    """
  end

  attr :region, EbirdLocation, required: true
  attr :country, EbirdLocation, required: true
  attr :current_scope, Kjogvi.Scope, required: true

  defp link_form(assigns) do
    ~H"""
    <div class="max-w-md flex items-start gap-2">
      <div class="grow">
        <LocationAutocomplete.location_autocomplete
          id={"link-autocomplete-#{@region.id}"}
          scope={@current_scope}
          filter={link_filter(@region, @country)}
          on_select_event="link_selected"
          on_select_params={%{"ebird_id" => @region.id}}
          placeholder="Search common locations..."
          compact={true}
        />
      </div>
      <button
        type="button"
        phx-click="cancel_link"
        class="px-2.5 py-1 text-xs sm:text-sm font-medium text-stone-600 bg-white hover:bg-stone-50 border border-stone-300 rounded"
      >
        Cancel
      </button>
    </div>
    """
  end

  # The location a row pairs with but has not committed to. Only the suggestion
  # pairings qualify: a :linked row carries a location too, but it is the link
  # itself, not a proposal.
  defp suggested_location(%{location: %Location{} = location, pairing: pairing})
       when pairing in [:code_suggestion, :name_suggestion],
       do: location

  defp suggested_location(_row), do: nil

  defp comparison_row_id(%{ebird: %EbirdLocation{id: id}}), do: "ebird-region-#{id}"
  defp comparison_row_id(%{location: %Location{id: id}}), do: "iso-leftover-#{id}"

  defp link_filter(%EbirdLocation{location_type: :subdivision1}, %EbirdLocation{
         location: %Location{} = country
       }) do
    Location.Filter.for_ebird_link(country)
  end

  defp link_filter(_region, _country), do: Location.Filter.for_ebird_link()
end
