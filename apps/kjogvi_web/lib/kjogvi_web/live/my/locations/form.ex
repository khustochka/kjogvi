defmodule KjogviWeb.Live.My.Locations.Form do
  @moduledoc """
  LiveView for creating and editing locations.

  The location struct is the single source of truth. Autocomplete components
  (parent, cached_parent, cached_city, cached_subdivision, cached_country)
  update related IDs and preloaded structs via send/handle_info.
  """

  use KjogviWeb, :live_view

  alias Kjogvi.Geo
  alias Kjogvi.Geo.Location
  alias Kjogvi.Repo
  alias Kjogvi.Search
  alias KjogviWeb.Live.Components.AutocompleteSearch

  @cached_fields [:cached_parent, :cached_city, :cached_subdivision, :cached_country]
  @cached_id_fields %{
    cached_parent: :cached_parent_id,
    cached_city: :cached_city_id,
    cached_subdivision: :cached_subdivision_id,
    cached_country: :cached_country_id
  }

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
        location =
          location
          |> Repo.preload(@cached_fields)
          |> Location.with_parent_id()

        location =
          Map.put(location, :parent, location.parent_id && Repo.get(Location, location.parent_id))

        {
          :noreply,
          socket
          |> assign(:page_title, "Edit #{location.name_en}")
          |> assign(:action, :edit)
          |> assign_location(location)
        }
    end
  end

  def handle_params(params, _url, socket) do
    parent_id = params["parent_id"] && String.to_integer(params["parent_id"])

    location =
      %Location{
        is_private: false,
        is_patch: false,
        cached_parent: nil,
        cached_city: nil,
        cached_subdivision: nil,
        cached_country: nil
      }
      |> apply_parent(parent_id)

    {
      :noreply,
      socket
      |> assign(:page_title, "New Location")
      |> assign(:action, :create)
      |> assign_location(location)
    }
  end

  defp assign_location(socket, location) do
    params = current_form_params(socket)
    changeset = Geo.change_location(location, merge_assoc_ids(params, location))

    socket
    |> assign(:location, location)
    |> assign(:form, to_form(changeset))
  end

  defp current_form_params(%{assigns: %{form: %Phoenix.HTML.Form{params: params}}})
       when is_map(params),
       do: params

  defp current_form_params(_), do: %{}

  @impl true
  def handle_event("validate", %{"location" => params}, socket) do
    changeset =
      socket.assigns.location
      |> Geo.change_location(merge_assoc_ids(params, socket.assigns.location))
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"location" => params}, socket) do
    params = merge_assoc_ids(params, socket.assigns.location)

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

  def handle_event("clear_parent", _params, socket) do
    location =
      socket.assigns.location
      |> apply_parent(nil)
      |> set_cached(:cached_parent, nil)
      |> set_cached(:cached_city, nil)
      |> set_cached(:cached_subdivision, nil)
      |> set_cached(:cached_country, nil)

    {:noreply, assign_location(socket, location)}
  end

  def handle_event("clear_cached", %{"field" => field}, socket) do
    location = set_cached(socket.assigns.location, String.to_existing_atom(field), nil)
    {:noreply, assign_location(socket, location)}
  end

  @impl true
  def handle_info({:autocomplete_select, "parent_selected", %{"result" => result}}, socket) do
    location = apply_parent(socket.assigns.location, result.id)
    {:noreply, assign_location(socket, location)}
  end

  def handle_info({:autocomplete_select, "cached_selected", params}, socket) do
    field = String.to_existing_atom(params["field"])
    result = params["result"]
    cached_struct = %Location{id: result.id, name_en: result.name_en}

    location = set_cached(socket.assigns.location, field, cached_struct)
    {:noreply, assign_location(socket, location)}
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
            current={@location.parent}
            on_select_event="parent_selected"
            on_clear_event="clear_parent"
          />
          <CoreComponents.input type="text" field={@form[:iso_code]} label="ISO code" />
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
        These fields are presentational, they should be modified separately from ancestry
      </p>

      <div class="grid grid-cols-1 sm:grid-cols-4 gap-4">
        <.autocomplete_row
          field="cached_parent"
          label="Cached parent"
          current={@location.cached_parent}
          on_select_event="cached_selected"
          on_select_params={%{"field" => "cached_parent"}}
          on_clear_event="clear_cached"
          on_clear_params={%{"field" => "cached_parent"}}
        />
        <.autocomplete_row
          field="cached_city"
          label="Cached city"
          current={@location.cached_city}
          on_select_event="cached_selected"
          on_select_params={%{"field" => "cached_city"}}
          on_clear_event="clear_cached"
          on_clear_params={%{"field" => "cached_city"}}
        />
        <.autocomplete_row
          field="cached_subdivision"
          label="Cached subdivision"
          current={@location.cached_subdivision}
          on_select_event="cached_selected"
          on_select_params={%{"field" => "cached_subdivision"}}
          on_clear_event="clear_cached"
          on_clear_params={%{"field" => "cached_subdivision"}}
        />
        <.autocomplete_row
          field="cached_country"
          label="Cached country"
          current={@location.cached_country}
          on_select_event="cached_selected"
          on_select_params={%{"field" => "cached_country"}}
          on_clear_event="clear_cached"
          on_clear_params={%{"field" => "cached_country"}}
        />
      </div>

      <div class="pt-2">
        <CoreComponents.input type="text" field={@form[:name_en]} label="English name" />
      </div>

      <div class="flex flex-wrap items-center gap-6 pt-2">
        <CoreComponents.input type="checkbox" field={@form[:is_private]} label="Private loc" />
        <CoreComponents.input type="checkbox" field={@form[:is_patch]} label="Patch" />
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 pt-2">
        <CoreComponents.input type="number" field={@form[:lat]} label="Latitude" step="0.000001" />
        <CoreComponents.input type="number" field={@form[:lon]} label="Longitude" step="0.000001" />
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
  attr :current, :any, default: nil
  attr :on_select_event, :string, required: true
  attr :on_select_params, :map, default: %{}
  attr :on_clear_event, :string, required: true
  attr :on_clear_params, :map, default: %{}

  defp autocomplete_row(assigns) do
    ~H"""
    <div class="flex items-end gap-2">
      <div class="flex-1">
        <.live_component
          module={AutocompleteSearch}
          id={"location_#{@field}_search"}
          label={@label}
          placeholder=""
          current_value={(@current && @current.name_en) || ""}
          hidden_name={"location[#{@field}_id]"}
          hidden_value={(@current && @current.id) || ""}
          search_fn={&Search.Location.search_locations/1}
          on_select_event={@on_select_event}
          on_select_params={@on_select_params}
        />
      </div>
      <button
        :if={@current}
        type="button"
        phx-click={@on_clear_event}
        phx-value-field={@on_clear_params["field"]}
        class="mb-1 px-3 py-2 text-sm text-stone-600 hover:text-stone-800 hover:bg-stone-100 rounded"
        aria-label="Clear"
      >
        <.icon name="hero-x-mark" class="w-4 h-4" />
      </button>
    </div>
    """
  end

  defp cancel_path(:edit, location), do: ~p"/my/locations/#{location.slug}"
  defp cancel_path(:create, _), do: ~p"/my/locations"

  # Sets parent_id, parent struct, and auto-fills cached_* slots based on
  # parent's ancestry chain (walked deepest-first; each ancestor goes into
  # the slot matching its location_type, deepest unclassified becomes
  # cached_parent).
  defp apply_parent(location, nil) do
    location
    |> Map.put(:parent_id, nil)
    |> Map.put(:parent, nil)
  end

  defp apply_parent(location, parent_id) do
    parent = Repo.get(Location, parent_id)
    chain = Location.ancestors(parent) ++ [parent]

    cached =
      Enum.reduce(chain, %{city: nil, subdivision: nil, country: nil}, fn loc, acc ->
        slot =
          case loc.location_type do
            "country" -> :country
            "region" -> :subdivision
            "city" -> :city
            _ -> nil
          end

        if slot && Map.fetch!(acc, slot) == nil, do: Map.put(acc, slot, loc), else: acc
      end)

    cached_parent =
      if parent.id in Enum.map(Map.values(cached), &(&1 && &1.id)),
        do: nil,
        else: parent

    location
    |> Map.put(:parent_id, parent.id)
    |> Map.put(:parent, parent)
    |> set_cached(:cached_parent, cached_parent)
    |> set_cached(:cached_city, cached.city)
    |> set_cached(:cached_subdivision, cached.subdivision)
    |> set_cached(:cached_country, cached.country)
  end

  defp set_cached(location, field, nil) do
    location
    |> Map.put(field, nil)
    |> Map.put(cached_id_field(field), nil)
  end

  defp set_cached(location, field, %Location{} = loc) do
    location
    |> Map.put(field, loc)
    |> Map.put(cached_id_field(field), loc.id)
  end

  defp cached_id_field(field), do: Map.fetch!(@cached_id_fields, field)

  defp merge_assoc_ids(params, location) do
    params
    |> Map.put("parent_id", location.parent_id)
    |> Map.put("cached_parent_id", location.cached_parent_id)
    |> Map.put("cached_city_id", location.cached_city_id)
    |> Map.put("cached_subdivision_id", location.cached_subdivision_id)
    |> Map.put("cached_country_id", location.cached_country_id)
  end
end
