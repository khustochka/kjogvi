defmodule KjogviWeb.Live.My.Locations.Form do
  @moduledoc """
  LiveView for creating and editing locations.

  State is split into:
    * `@location` — the pristine DB row (or a fresh struct for `:create`). Never
      mutated; passed to the context on save.
    * `@form` — the changeset wrapped via `to_form/1`; the source of truth for
      every editable field. Ancestry is set through a single virtual `parent_id`,
      from which the changeset derives the five level FK columns.
    * `@parent_struct` — the loaded parent location, both the label for the
      parent autocomplete and the map picker's fallback center coords.
  """

  use KjogviWeb, :live_view

  alias Kjogvi.Accounts.User
  alias Kjogvi.Geo
  alias Kjogvi.Geo.Location
  alias Kjogvi.Repo
  alias KjogviWeb.Live.Components.LocationAutocomplete

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :container_class, "max-w-5xl")}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _url, socket) do
    location = Geo.location_by_slug_scope(socket.assigns.current_scope, slug)

    cond do
      is_nil(location) ->
        {:noreply,
         socket
         |> put_flash(:error, "Location not found")
         |> push_navigate(to: ~p"/my/locations")}

      not User.owns?(socket.assigns.current_scope.current_user, location) ->
        {:noreply,
         socket
         |> put_flash(:error, "You can only edit your own locations")
         |> push_navigate(to: ~p"/my/locations/#{location.slug}")}

      true ->
        parent_id = Location.parent_id_from_levels(location)

        parent_struct =
          parent_id && Location.Query.put_levels(load_parent(parent_id))

        {
          :noreply,
          socket
          |> assign(:page_title, "Edit #{location.name_en}")
          |> assign(:action, :edit)
          |> assign(:location, location)
          |> assign(:parent_struct, parent_struct)
          |> assign_form(initial_params(location, parent_id))
        }
    end
  end

  def handle_params(params, _url, socket) do
    parent_id = params["parent_id"] && String.to_integer(params["parent_id"])

    parent_struct =
      parent_id && Location.Query.put_levels(load_parent(parent_id))

    {
      :noreply,
      socket
      |> assign(:page_title, "New Location")
      |> assign(:action, :create)
      |> assign(:location, %Location{is_private: false})
      |> assign(:parent_struct, parent_struct)
      |> assign_form(%{"parent_id" => parent_id})
    }
  end

  defp load_parent(nil), do: nil
  defp load_parent(parent_id), do: Repo.get(Location, parent_id)

  defp assign_form(socket, params) do
    changeset = Geo.change_location(socket.assigns.location, params)
    assign(socket, :form, to_form(changeset))
  end

  defp current_form_params(%{assigns: %{form: %Phoenix.HTML.Form{params: params}}})
       when is_map(params),
       do: params

  defp current_form_params(_), do: %{}

  defp revalidate(socket, params) do
    changeset =
      socket.assigns.location
      |> Geo.change_location(params)
      |> Map.put(:action, :validate)

    assign(socket, :form, to_form(changeset))
  end

  @impl true
  def handle_event("validate", %{"location" => params}, socket) do
    {:noreply, revalidate(socket, params)}
  end

  def handle_event("map_picked", %{"lat" => lat, "lon" => lon}, socket) do
    params = current_form_params(socket) |> Map.merge(%{"lat" => lat, "lon" => lon})
    {:noreply, revalidate(socket, params)}
  end

  def handle_event("map_cleared", _params, socket) do
    params = current_form_params(socket) |> Map.merge(%{"lat" => nil, "lon" => nil})
    {:noreply, revalidate(socket, params)}
  end

  def handle_event("save", %{"location" => params}, socket) do
    scope = socket.assigns.current_scope

    result =
      case socket.assigns.action do
        :create -> Geo.create_location(scope, params)
        :edit -> Geo.update_location(scope, socket.assigns.location, params)
      end

    case result do
      {:ok, location} ->
        {:noreply,
         socket
         |> put_flash(:info, "Location saved")
         |> push_navigate(to: ~p"/my/locations/#{location.slug}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}

      {:error, :forbidden} ->
        {:noreply,
         socket
         |> put_flash(:error, "You can only edit your own locations")
         |> push_navigate(to: ~p"/my/locations")}
    end
  end

  @impl true
  def handle_info({:autocomplete_select, "parent_selected", %{"result" => result}}, socket) do
    parent_struct = Location.Query.put_levels(load_parent(result.id))
    params = current_form_params(socket) |> Map.put("parent_id", result.id)

    {:noreply,
     socket
     |> assign(:parent_struct, parent_struct)
     |> revalidate(params)}
  end

  def handle_info({:autocomplete_clear, "parent_selected", _params}, socket) do
    params = current_form_params(socket) |> Map.put("parent_id", nil)

    {:noreply,
     socket
     |> assign(:parent_struct, nil)
     |> revalidate(params)}
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

    <.h1>
      {if @action == :create, do: "New Location", else: "Edit #{@location.name_en}"}
    </.h1>

    <.form for={@form} id="location-form" phx-submit="save" phx-change="validate" class="space-y-4">
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div class="space-y-4">
          <CoreComponents.input type="text" field={@form[:slug]} label="Slug" />
          <.autocomplete_row
            field="parent"
            label="Parent"
            current_label={@parent_struct && Location.long_name(:private, @parent_struct)}
            current_id={@form[:parent_id].value}
            on_select_event="parent_selected"
            scope={@current_scope}
          />
          <ul
            :if={ancestry_errors(@form) != []}
            id="location-ancestry-errors"
            class="text-sm text-rose-600"
          >
            <li :for={msg <- ancestry_errors(@form)}>{msg}</li>
          </ul>
        </div>

        <div>
          <label
            for={@form[:location_type].id}
            class="block text-sm font-medium font-header leading-6 text-zinc-800"
          >
            Locus type
          </label>
          <select
            id={@form[:location_type].id}
            name={@form[:location_type].name}
            size={length(Location.user_assignable_types())}
            class="inline-block w-auto min-w-48 pr-8 rounded-md border border-gray-300 bg-white shadow-sm focus:border-zinc-400 focus:ring-0 text-base"
          >
            {Phoenix.HTML.Form.options_for_select(
              Location.user_assignable_types(),
              @form[:location_type].value || ""
            )}
          </select>
          <ul
            :if={@form[:location_type].errors != []}
            id="location-type-errors"
            class="mt-1 text-sm text-rose-600"
          >
            <li :for={{msg, _opts} <- @form[:location_type].errors}>{msg}</li>
          </ul>
        </div>
      </div>

      <div :if={@parent_struct} id="location-ancestry-summary" class="text-sm text-stone-500 pt-1">
        Ancestry: {Location.long_name(:private, @parent_struct)}
      </div>

      <div class="pt-2">
        <CoreComponents.input type="text" field={@form[:name_en]} label="English name" />
      </div>

      <div class="flex flex-wrap items-end gap-6 pt-2">
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
  attr :scope, Kjogvi.Scope, required: true

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
      scope={@scope}
    />
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

  # Slot-occupancy/parent errors don't map to a visible input (the level FKs are
  # derived from the parent), so surface them near the parent picker.
  @ancestry_error_fields [:parent_id | Location.level_fks()]

  defp ancestry_errors(%Phoenix.HTML.Form{} = form) do
    for field <- @ancestry_error_fields,
        {msg, _opts} <- Keyword.get_values(form.source.errors, field) do
      "#{humanize_field(field)} #{msg}"
    end
  end

  defp humanize_field(:parent_id), do: "Parent"

  # `Phoenix.Naming.humanize/1` already strips the `_id` suffix (`:country_id`
  # → "Country").
  defp humanize_field(field), do: Phoenix.Naming.humanize(field)

  # Initial form params reconstructed from a loaded location (edit mode).
  defp initial_params(location, parent_id) do
    %{
      "slug" => location.slug,
      "name_en" => location.name_en,
      "location_type" => location.location_type,
      "is_private" => location.is_private,
      "lat" => location.lat,
      "lon" => location.lon,
      "parent_id" => parent_id
    }
  end
end
