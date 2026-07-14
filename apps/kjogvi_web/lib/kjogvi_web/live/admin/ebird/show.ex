defmodule KjogviWeb.Live.Admin.Ebird.Show do
  @moduledoc """
  Matching workbench for one eBird country: the country row, then its
  subdivision1s as a side-by-side eBird-vs-ISO comparison
  (`Kjogvi.Geo.Ebird.subdivision1_comparison/1`) — paired rows on one line,
  each side's leftovers against an empty cell. The match passes button and the
  manual resolution actions (link via autocomplete, unlink, create-from-eBird)
  act on the eBird side; the ISO column is read-only context.
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
  def handle_event("run_match", _params, socket) do
    summary = Geo.Ebird.match_country(socket.assigns.country_code)

    {:noreply,
     socket
     |> put_flash(
       :info,
       "Matched #{summary.code} by code and #{summary.name} by name; #{summary.left} left unmatched."
     )
     |> load_country()}
  end

  def handle_event("start_link", %{"id" => id}, socket) do
    {:noreply, assign(socket, :linking_id, String.to_integer(id))}
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
  def handle_info({:autocomplete_select, "link_selected", params}, socket) do
    %{"result" => location, "ebird_id" => ebird_id} = params
    region = find_region(socket, ebird_id)

    socket =
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

    {:noreply,
     socket
     |> assign(:linking_id, nil)
     |> load_country()}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  defp load_country(socket) do
    country_code = socket.assigns.country_code
    regions = Geo.Ebird.matchable_locations(country_code)

    socket
    |> assign(:country, Enum.find(regions, &(&1.location_type == :country)))
    |> assign(:regions, regions)
    |> assign(:comparison, Geo.Ebird.subdivision1_comparison(country_code))
    |> assign(:stats, Geo.Ebird.country_status(country_code))
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
          </p>
        </div>
        <.button id="run-match-button" phx-click="run_match" class="mb-1">
          Run match
        </.button>
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
            <%!-- Columns of equal share with a fixed-width marker between, so the
            two sides' codes and names line up down the whole table. --%>
            <div class="grid sm:grid-cols-[minmax(0,1fr)_5.5rem_minmax(0,1fr)] gap-x-3 gap-y-1 items-baseline">
              <%!-- eBird side --%>
              <div class="grid grid-cols-[5.5rem_minmax(0,1fr)] gap-x-2 items-baseline">
                <span :if={row.ebird} class="font-mono text-sm text-stone-500">
                  {row.ebird.code}
                </span>
                <span :if={row.ebird} class="font-medium">{row.ebird.name}</span>
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
            </div>

            <div :if={row.ebird} class="flex flex-wrap gap-2">
              <.region_actions region={row.ebird} country={@country} />
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

  attr :pairing, :atom, required: true

  # The middle column: what ties (or fails to tie) the two sides of a row.
  defp pairing_marker(assigns) do
    ~H"""
    <span class="flex justify-center text-sm">
      <span :if={@pairing == :linked} class="text-forest-600" title="Linked">&rarr;</span>
      <span
        :if={@pairing == :code_suggestion}
        class="text-stone-400"
        title="Same ISO code, not linked yet — Run match links this"
      >
        &rarr;
      </span>
      <span
        :if={@pairing == :name_suggestion}
        class="px-2 py-0.5 text-xs font-medium rounded-full bg-amber-100 text-amber-700"
        title="Codes differ but the names match — Run match links this"
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
        phx-click="start_link"
        phx-value-id={@region.id}
        class="px-2.5 py-1 text-xs sm:text-sm font-medium text-forest-700 bg-forest-50 hover:bg-forest-100 border border-forest-300 rounded"
      >
        Link
      </button>
      <button
        :if={@region.location_type == :country or @country.location != nil}
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

  defp comparison_row_id(%{ebird: %EbirdLocation{id: id}}), do: "ebird-region-#{id}"
  defp comparison_row_id(%{location: %Location{id: id}}), do: "iso-leftover-#{id}"

  defp link_filter(%EbirdLocation{location_type: :subdivision1}, %EbirdLocation{
         location: %Location{} = country
       }) do
    Location.Filter.for_ebird_link(country)
  end

  defp link_filter(_region, _country), do: Location.Filter.for_ebird_link()
end
