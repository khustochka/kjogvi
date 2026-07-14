defmodule KjogviWeb.Live.Admin.Ebird.Show do
  @moduledoc """
  Matching workbench for one eBird country: its country and subdivision1 rows
  with their linked common locations, the match passes button, and the manual
  resolution actions — link (autocomplete), unlink, create-from-eBird.
  ISO-only subdivisions are listed for context; they need no action.
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
    regions = Geo.Ebird.matchable_locations(socket.assigns.country_code)
    country = Enum.find(regions, &(&1.location_type == :country))

    socket
    |> assign(:country, country)
    |> assign(:regions, regions)
    |> assign(:stats, Geo.Ebird.country_status(socket.assigns.country_code))
    |> assign(:iso_leftovers, Geo.Ebird.unmatched_iso_subdivision1s(socket.assigns.country_code))
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

      <%!-- eBird regions --%>
      <div>
        <.h2 class="mb-3!">eBird regions</.h2>

        <ul id="ebird-regions" class="border border-stone-200 rounded-lg divide-y divide-stone-100">
          <li
            :for={region <- @regions}
            id={"ebird-region-#{region.id}"}
            class="px-4 py-2.5 space-y-2"
          >
            <div class="flex flex-wrap items-center gap-x-3 gap-y-1">
              <span class="font-mono text-sm text-stone-500 shrink-0">{region.code}</span>
              <span class="font-medium">{region.name}</span>
              <.type_badge type={region.location_type} />

              <%= if region.location do %>
                <span class="text-stone-400">&rarr;</span>
                <.link
                  navigate={~p"/admin/locations/#{region.location.slug}"}
                  class="text-forest-700"
                  phx-no-format
                >{Location.long_name(:private, region.location)}</.link>
                <span
                  :if={EbirdLocation.code_match?(region)}
                  class="inline-block px-2 py-0.5 text-xs font-medium rounded-full bg-forest-100 text-forest-600"
                >
                  by code
                </span>
                <span
                  :if={!EbirdLocation.code_match?(region)}
                  class="inline-block px-2 py-0.5 text-xs font-medium rounded-full bg-amber-100 text-amber-700"
                  title="Linked to a location whose ISO code differs from the eBird code"
                >
                  other
                </span>
                <button
                  type="button"
                  phx-click="unlink"
                  phx-value-id={region.id}
                  data-confirm={"Unlink #{region.code} from #{region.location.name_en}?"}
                  class="ml-auto px-2.5 py-1 text-xs sm:text-sm font-medium text-rose-700 bg-rose-50 hover:bg-rose-100 border border-rose-300 rounded"
                >
                  Unlink
                </button>
              <% else %>
                <span class="text-sm text-stone-400">unmatched</span>
                <span class="ml-auto flex flex-wrap gap-2">
                  <button
                    type="button"
                    phx-click="start_link"
                    phx-value-id={region.id}
                    class="px-2.5 py-1 text-xs sm:text-sm font-medium text-forest-700 bg-forest-50 hover:bg-forest-100 border border-forest-300 rounded"
                  >
                    Link
                  </button>
                  <button
                    :if={region.location_type == :country or @country.location != nil}
                    type="button"
                    phx-click="create_location"
                    phx-value-id={region.id}
                    data-confirm={"Create a common location from #{region.code} and link it?"}
                    class="px-2.5 py-1 text-xs sm:text-sm font-medium text-stone-700 bg-stone-50 hover:bg-stone-100 border border-stone-300 rounded"
                  >
                    Create from eBird
                  </button>
                </span>
              <% end %>
            </div>

            <div :if={@linking_id == region.id} class="max-w-md flex items-start gap-2">
              <div class="grow">
                <LocationAutocomplete.location_autocomplete
                  id={"link-autocomplete-#{region.id}"}
                  scope={@current_scope}
                  filter={link_filter(region, @country)}
                  on_select_event="link_selected"
                  on_select_params={%{"ebird_id" => region.id}}
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
          </li>
        </ul>
      </div>

      <%!-- ISO-only subdivisions --%>
      <div :if={@iso_leftovers != []} id="iso-leftovers">
        <.h2 class="mb-1!">ISO subdivisions without an eBird counterpart</.h2>
        <p class="mb-3 text-sm text-stone-500">
          These exist as common locations and need no action.
        </p>

        <ul class="border border-stone-200 rounded-lg divide-y divide-stone-100">
          <li
            :for={location <- @iso_leftovers}
            id={"iso-leftover-#{location.id}"}
            class="px-4 py-2.5 flex flex-wrap items-center gap-x-3 gap-y-1"
          >
            <span class="font-mono text-sm text-stone-500 shrink-0">
              {location.iso_code && String.upcase(location.iso_code)}
            </span>
            <.link
              navigate={~p"/admin/locations/#{location.slug}"}
              class="font-medium text-forest-700"
              phx-no-format
            >{location.name_en}</.link>
          </li>
        </ul>
      </div>
    </div>
    """
  end

  defp link_filter(%EbirdLocation{location_type: :subdivision1}, %EbirdLocation{
         location: %Location{} = country
       }) do
    Location.Filter.for_ebird_link(country)
  end

  defp link_filter(_region, _country), do: Location.Filter.for_ebird_link()
end
