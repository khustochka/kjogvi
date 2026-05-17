defmodule KjogviWeb.Live.My.Locations.Form do
  @moduledoc """
  LiveView for creating and editing locations.

  State is split into three assigns:
    * `@location` — the pristine DB row (or a fresh struct for `:create`). Never
      mutated; passed to the context on save.
    * `@form` — the changeset wrapped via `to_form/1`; the source of truth for
      every editable field.
    * `@cached_labels` — display strings for autocomplete fields (parent and
      cached_*), since the changeset only carries IDs.
    * `@parent_struct` — the loaded parent location, needed by the map picker
      for its fallback center coords.
  """

  use KjogviWeb, :live_view

  alias Kjogvi.Geo
  alias Kjogvi.Geo.Location
  alias Kjogvi.Repo
  alias KjogviWeb.Live.Components.LocationAutocomplete

  @cached_fields [:cached_parent, :cached_city, :cached_subdivision, :cached_country]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :container_class, "max-w-5xl")}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _url, socket) do
    case Geo.location_by_slug_scope(socket.assigns.current_scope, slug) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Location not found")
         |> push_navigate(to: ~p"/my/locations")}

      location ->
        location = Repo.preload(location, @cached_fields) |> Location.with_parent_id()
        parent_struct = location.parent_id && Repo.get(Location, location.parent_id)

        {
          :noreply,
          socket
          |> assign(:page_title, "Edit #{location.name_en}")
          |> assign(:action, :edit)
          |> assign(:location, location)
          |> assign(:parent_struct, parent_struct)
          |> assign(:cached_labels, labels_from_record(location, parent_struct))
          |> assign_form(initial_params(location, parent_struct))
        }
    end
  end

  def handle_params(params, _url, socket) do
    parent_id = params["parent_id"] && String.to_integer(params["parent_id"])
    parent_struct = parent_id && Repo.get(Location, parent_id)
    {parent_ids, parent_labels} = derive_from_parent(parent_struct)

    {
      :noreply,
      socket
      |> assign(:page_title, "New Location")
      |> assign(:action, :create)
      |> assign(:location, %Location{is_private: false})
      |> assign(:parent_struct, parent_struct)
      |> assign(:cached_labels, parent_labels)
      |> assign_form(parent_ids)
    }
  end

  defp assign_form(socket, params) do
    changeset =
      socket.assigns.location
      |> Geo.change_location(params)

    assign(socket, :form, to_form(changeset))
  end

  defp current_form_params(%{assigns: %{form: %Phoenix.HTML.Form{params: params}}})
       when is_map(params),
       do: params

  defp current_form_params(_), do: %{}

  @impl true
  def handle_event("validate", %{"location" => params}, socket) do
    changeset =
      socket.assigns.location
      |> Geo.change_location(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("map_picked", %{"lat" => lat, "lon" => lon}, socket) do
    params = current_form_params(socket) |> Map.merge(%{"lat" => lat, "lon" => lon})

    changeset =
      socket.assigns.location
      |> Geo.change_location(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("map_cleared", _params, socket) do
    params = current_form_params(socket) |> Map.merge(%{"lat" => nil, "lon" => nil})

    changeset =
      socket.assigns.location
      |> Geo.change_location(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"location" => params}, socket) do
    result =
      case socket.assigns.action do
        :create -> Geo.create_location(params)
        :edit -> Geo.update_location(socket.assigns.location, params)
      end

    case result do
      {:ok, location} ->
        {:noreply,
         socket
         |> put_flash(:info, "Location saved")
         |> push_navigate(to: ~p"/my/locations/#{location.slug}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def handle_info({:autocomplete_select, "parent_selected", %{"result" => result}}, socket) do
    parent_struct = Repo.get(Location, result.id)
    {ids, labels} = derive_from_parent(parent_struct)

    params = current_form_params(socket) |> Map.merge(ids)

    changeset =
      socket.assigns.location
      |> Geo.change_location(params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:parent_struct, parent_struct)
     |> assign(:cached_labels, labels)
     |> assign(:form, to_form(changeset))}
  end

  def handle_info({:autocomplete_clear, "parent_selected", _params}, socket) do
    {ids, labels} = derive_from_parent(nil)
    params = current_form_params(socket) |> Map.merge(ids)

    changeset =
      socket.assigns.location
      |> Geo.change_location(params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:parent_struct, nil)
     |> assign(:cached_labels, labels)
     |> assign(:form, to_form(changeset))}
  end

  def handle_info({:autocomplete_select, "cached_selected", params}, socket) do
    field = params["field"]
    result = params["result"]
    field_atom = String.to_existing_atom(field)

    labels = Map.put(socket.assigns.cached_labels, field_atom, result.name_en)
    form_params = current_form_params(socket) |> Map.put("#{field}_id", result.id)

    changeset =
      socket.assigns.location
      |> Geo.change_location(form_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:cached_labels, labels)
     |> assign(:form, to_form(changeset))}
  end

  def handle_info({:autocomplete_clear, "cached_selected", %{"field" => field}}, socket) do
    field_atom = String.to_existing_atom(field)
    labels = Map.put(socket.assigns.cached_labels, field_atom, nil)
    form_params = current_form_params(socket) |> Map.put("#{field}_id", nil)

    changeset =
      socket.assigns.location
      |> Geo.change_location(form_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:cached_labels, labels)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <nav id="location-breadcrumbs" class="text-sm text-stone-500 mb-4">
      <.breadcrumb_link href={~p"/my/locations"}>Locations</.breadcrumb_link>
      <span :if={@action == :edit} class="mx-1 text-stone-400">/</span>
      <.breadcrumb_link
        :if={@action == :edit}
        href={~p"/my/locations/#{@location.slug}"}
        phx-no-format
      >{@location.name_en}</.breadcrumb_link>
      <span class="mx-1 text-stone-400">/</span>
      <span class="text-stone-700">
        {if @action == :create, do: "New Location", else: "Edit"}
      </span>
    </nav>

    <CoreComponents.header>
      {if @action == :create, do: "New Location", else: "Edit #{@location.name_en}"}
    </CoreComponents.header>

    <.form for={@form} id="location-form" phx-submit="save" phx-change="validate" class="space-y-4">
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div class="space-y-4">
          <CoreComponents.input type="text" field={@form[:slug]} label="Slug" />
          <.autocomplete_row
            field="parent"
            label="Parent"
            current_label={@cached_labels[:parent]}
            current_id={@form[:parent_id].value}
            on_select_event="parent_selected"
          />
        </div>

        <div>
          <label
            for={@form[:location_type].id}
            class="block text-sm font-semibold leading-6 text-zinc-800"
          >
            Locus type
          </label>
          <select
            id={@form[:location_type].id}
            name={@form[:location_type].name}
            size={length(Location.location_types()) + 1}
            class="mt-2 inline-block w-auto min-w-48 pr-8 rounded-md border border-gray-300 bg-white shadow-sm focus:border-zinc-400 focus:ring-0 text-base"
          >
            {Phoenix.HTML.Form.options_for_select(
              [{"— none —", ""} | Location.location_types()],
              @form[:location_type].value || ""
            )}
          </select>
        </div>
      </div>

      <p class="text-stone-500 text-sm pt-2">
        These fields determine the segments of the location's full display name.
      </p>

      <div class="grid grid-cols-1 sm:grid-cols-4 gap-4">
        <.autocomplete_row
          field="cached_parent"
          label="Cached parent"
          current_label={@cached_labels[:cached_parent]}
          current_id={@form[:cached_parent_id].value}
          on_select_event="cached_selected"
          on_select_params={%{"field" => "cached_parent"}}
        />
        <.autocomplete_row
          field="cached_city"
          label="Cached city"
          current_label={@cached_labels[:cached_city]}
          current_id={@form[:cached_city_id].value}
          on_select_event="cached_selected"
          on_select_params={%{"field" => "cached_city"}}
        />
        <.cached_label
          id="location_cached_subdivision"
          label="Cached subdivision"
          current_label={@cached_labels[:cached_subdivision]}
        />
        <.cached_label
          id="location_cached_country"
          label="Cached country"
          current_label={@cached_labels[:cached_country]}
        />
      </div>

      <div class="pt-2">
        <CoreComponents.input type="text" field={@form[:name_en]} label="English name" />
      </div>

      <div class="flex flex-wrap items-end gap-6 pt-2">
        <div class="w-20">
          <CoreComponents.input type="text" field={@form[:iso_code]} label="ISO" />
        </div>
        <div class="flex items-center h-[38px]">
          <CoreComponents.input type="checkbox" field={@form[:is_private]} label="Private loc" />
        </div>
      </div>

      <.map_picker lat={@form[:lat]} lon={@form[:lon]} parent={@parent_struct} />

      <div class="flex flex-wrap items-end gap-4 pt-2">
        <div class="w-40">
          <CoreComponents.input type="number" field={@form[:lat]} label="Latitude" step="0.000001" />
        </div>
        <div class="w-40">
          <CoreComponents.input
            type="number"
            field={@form[:lon]}
            label="Longitude"
            step="0.000001"
          />
        </div>
        <button
          :if={@form[:lat].value && @form[:lon].value}
          type="button"
          phx-click="map_cleared"
          class="mb-1 inline-flex items-center gap-1 px-3 py-2 text-sm font-medium text-stone-700 bg-stone-100 hover:bg-stone-200 rounded"
        >
          <.icon name="hero-x-mark" class="w-4 h-4" /> Clear coordinates
        </button>
      </div>

      <div class="flex gap-4 pt-6">
        <button
          type="submit"
          phx-disable-with="Saving..."
          class="inline-flex items-center gap-2 rounded-lg bg-green-600 px-6 py-2 text-sm font-semibold text-white hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          Save
        </button>

        <.action_button navigate={cancel_path(@action, @location)} variant="secondary">
          Cancel
        </.action_button>
      </div>
    </.form>
    """
  end

  attr :field, :string, required: true
  attr :label, :string, required: true
  attr :current_label, :any, default: nil
  attr :current_id, :any, default: nil
  attr :on_select_event, :string, required: true
  attr :on_select_params, :map, default: %{}

  defp autocomplete_row(assigns) do
    ~H"""
    <LocationAutocomplete.location_autocomplete
      id={"location_#{@field}_search"}
      label={@label}
      placeholder=""
      current_value={@current_label || ""}
      hidden_name={"location[#{@field}_id]"}
      hidden_value={@current_id || ""}
      on_select_event={@on_select_event}
      on_select_params={@on_select_params}
    />
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :current_label, :any, default: nil

  defp cached_label(assigns) do
    ~H"""
    <div id={@id}>
      <span class="block text-sm font-semibold leading-6 text-zinc-800">{@label}</span>
      <div
        id={"#{@id}_value"}
        aria-disabled="true"
        class="mt-2 block w-full rounded-lg border border-zinc-200 bg-zinc-50 px-3 py-2 text-zinc-500 sm:text-sm sm:leading-6"
      >
        <span class="block min-h-6">{@current_label}</span>
      </div>
    </div>
    """
  end

  attr :lat, Phoenix.HTML.FormField, required: true
  attr :lon, Phoenix.HTML.FormField, required: true
  attr :parent, :any, default: nil

  defp map_picker(assigns) do
    assigns =
      assigns
      |> assign(:parent_lat, assigns.parent && assigns.parent.lat)
      |> assign(:parent_lon, assigns.parent && assigns.parent.lon)

    ~H"""
    <div class="pt-2">
      <span class="block text-sm font-semibold text-zinc-800 mb-1">Map</span>
      <p class="text-xs text-stone-500 mb-2">
        Click on the map to place a marker. Drag marker to adjust.
      </p>
      <div
        id="location-map-picker"
        phx-hook="LocationMapPicker"
        data-lat={@lat.value && to_string(@lat.value)}
        data-lon={@lon.value && to_string(@lon.value)}
        data-parent-lat={@parent_lat && to_string(@parent_lat)}
        data-parent-lon={@parent_lon && to_string(@parent_lon)}
        class="w-full h-80 rounded-lg border border-stone-200 overflow-hidden bg-stone-100"
      >
        <div id="location-map-picker-canvas" phx-update="ignore" class="w-full h-full"></div>
      </div>
    </div>
    """
  end

  defp cancel_path(:edit, location), do: ~p"/my/locations/#{location.slug}"
  defp cancel_path(:create, _), do: ~p"/my/locations"

  # Initial form params reconstructed from a loaded location (edit mode).
  defp initial_params(location, parent_struct) do
    %{
      "slug" => location.slug,
      "name_en" => location.name_en,
      "location_type" => location.location_type,
      "iso_code" => location.iso_code,
      "is_private" => location.is_private,
      "lat" => location.lat,
      "lon" => location.lon,
      "parent_id" => parent_struct && parent_struct.id,
      "cached_parent_id" => location.cached_parent_id,
      "cached_city_id" => location.cached_city_id
    }
  end

  # Given a parent location (or nil), derives the four cached IDs and the five
  # display labels (parent + four cached_*). Walks the parent's ancestry chain
  # deepest-first; each ancestor goes into the slot matching its location_type,
  # and the deepest unclassified non-self ancestor becomes cached_parent.
  defp derive_from_parent(nil) do
    {
      %{
        "parent_id" => nil,
        "cached_parent_id" => nil,
        "cached_city_id" => nil
      },
      empty_labels()
    }
  end

  defp derive_from_parent(%Location{} = parent) do
    cached = classify_ancestry(parent)
    cached_parent = if parent.id in classified_ids(cached), do: nil, else: parent

    {ids_from_parent(parent, cached_parent, cached),
     labels_from_parent(parent, cached_parent, cached)}
  end

  defp classify_ancestry(parent) do
    chain = Location.ancestors(parent) ++ [parent]

    Enum.reduce(chain, %{city: nil, subdivision: nil, country: nil}, &place_in_slot/2)
  end

  defp place_in_slot(loc, acc) do
    case slot_for(loc.location_type) do
      nil -> acc
      slot -> if Map.fetch!(acc, slot) == nil, do: Map.put(acc, slot, loc), else: acc
    end
  end

  defp slot_for("country"), do: :country
  defp slot_for("region"), do: :subdivision
  defp slot_for("city"), do: :city
  defp slot_for(_), do: nil

  defp classified_ids(cached), do: Enum.map(Map.values(cached), &(&1 && &1.id))

  defp ids_from_parent(parent, cached_parent, cached) do
    %{
      "parent_id" => parent.id,
      "cached_parent_id" => cached_parent && cached_parent.id,
      "cached_city_id" => cached[:city] && cached[:city].id
    }
  end

  defp labels_from_parent(parent, cached_parent, cached) do
    %{
      parent: parent.name_en,
      cached_parent: cached_parent && cached_parent.name_en,
      cached_city: cached[:city] && cached[:city].name_en,
      cached_subdivision: cached[:subdivision] && cached[:subdivision].name_en,
      cached_country: cached[:country] && cached[:country].name_en
    }
  end

  # Labels for editing an existing location: read from preloaded cached_*
  # associations plus the parent struct.
  defp labels_from_record(location, parent_struct) do
    %{
      parent: parent_struct && parent_struct.name_en,
      cached_parent: location.cached_parent && location.cached_parent.name_en,
      cached_city: location.cached_city && location.cached_city.name_en,
      cached_subdivision: location.cached_subdivision && location.cached_subdivision.name_en,
      cached_country: location.cached_country && location.cached_country.name_en
    }
  end

  defp empty_labels do
    %{
      parent: nil,
      cached_parent: nil,
      cached_city: nil,
      cached_subdivision: nil,
      cached_country: nil
    }
  end
end
