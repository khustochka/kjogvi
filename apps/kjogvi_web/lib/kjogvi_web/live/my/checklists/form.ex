defmodule KjogviWeb.Live.My.Checklists.Form do
  @moduledoc """
  LiveView for creating and editing checklists.

  Uses the checklist struct as single source of truth. The checklist holds:
  - All field values
  - Nested observations with taxon structs (for display names)
  - Location struct (for display name)

  The form is derived from the checklist via `to_form(Birding.change_checklist(checklist))`.
  """

  use KjogviWeb, :live_view

  alias Kjogvi.Birding
  alias Kjogvi.Geo
  alias Kjogvi.Geo.Location
  alias KjogviWeb.BaseComponents
  alias KjogviWeb.Live.Components.LocationAutocomplete
  alias KjogviWeb.Live.Components.MonthCalendar
  alias KjogviWeb.Live.My.Checklists.ObservationForm

  @impl true
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> assign(:marked_for_deletion, MapSet.new())
      |> assign(:container_class, "max-w-7xl")
      |> assign(:effort_types, Birding.Checklist.effort_types())
    }
  end

  @impl true
  def handle_params(%{"id" => id}, _url, %{assigns: assigns} = socket) do
    checklist = Birding.fetch_checklist_for_edit(assigns.current_scope.current_user, id)
    # Preload taxa on observations for display
    observations_with_taxa = Birding.preload_taxa_and_species(checklist.observations)
    checklist = %{checklist | observations: observations_with_taxa}

    {
      :noreply,
      socket
      |> assign(:page_title, "Edit Checklist ##{checklist.id}")
      |> assign(:action, :edit)
      |> assign_checklist(checklist)
    }
  end

  def handle_params(_params, _url, %{assigns: assigns} = socket) do
    checklist = Birding.new_checklist(assigns.current_scope.current_user)
    checklist = %{checklist | observations: [Birding.new_observation()]}

    {
      :noreply,
      socket
      |> assign(:page_title, "New Checklist")
      |> assign(:action, :create)
      |> assign_checklist(checklist)
    }
  end

  # Helper to update checklist and derive form
  defp assign_checklist(socket, checklist) do
    socket
    |> assign(:checklist, checklist)
    |> assign(:form, to_form(Birding.change_checklist(checklist)))
  end

  @impl true
  def handle_event("add_observation", _params, socket) do
    checklist = socket.assigns.checklist

    new_observation = %Kjogvi.Birding.Observation{
      id: nil,
      checklist_id: nil,
      taxon_key: nil,
      taxon: nil,
      quantity: nil,
      voice: false,
      notes: nil,
      private_notes: nil,
      hidden: false,
      unreported: false
    }

    updated_checklist = %{checklist | observations: checklist.observations ++ [new_observation]}

    {:noreply, assign_checklist(socket, updated_checklist)}
  end

  def handle_event("remove_observation", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    observation = Enum.at(socket.assigns.checklist.observations, index)

    do_remove_observation(socket, index, observation)
  end

  def handle_event("restore_observation", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)

    {
      :noreply,
      socket
      |> assign(:marked_for_deletion, MapSet.delete(socket.assigns.marked_for_deletion, index))
    }
  end

  def handle_event("sync_checklist", %{"checklist" => checklist_params}, socket) do
    # Sync form field values to checklist struct
    checklist = socket.assigns.checklist
    updated_checklist = merge_params_into_checklist(checklist, checklist_params)
    changeset = Birding.change_checklist(updated_checklist)

    {:noreply, assign(socket, :checklist, updated_checklist) |> assign(:form, to_form(changeset))}
  end

  def handle_event("save", %{"checklist" => checklist_params}, %{assigns: assigns} = socket) do
    case do_save_checklist(
           assigns.action,
           assigns.checklist,
           checklist_params,
           assigns.current_scope.current_user
         ) do
      {:ok, checklist} ->
        {
          :noreply,
          socket
          |> put_flash(:info, "Checklist saved successfully")
          |> push_navigate(to: ~p"/my/checklists/#{checklist.id}")
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {
          :noreply,
          socket
          |> assign(:form, to_form(changeset))
        }
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <nav id="checklist-breadcrumbs" class="text-sm text-stone-500 mb-4">
      <.breadcrumb_link href={~p"/my/checklists"}>Checklists</.breadcrumb_link>
      <span :if={@action == :edit} class="mx-1 text-stone-400">/</span>
      <.breadcrumb_link
        :if={@action == :edit}
        href={~p"/my/checklists/#{@checklist.id}"}
        phx-no-format
      >Checklist #{@checklist.id}</.breadcrumb_link>
      <span class="mx-1 text-stone-400">/</span>
      <span class="text-stone-700">
        {if @action == :create, do: "New Checklist", else: "Edit"}
      </span>
    </nav>

    <.h1>
      {if @action == :create, do: "New Checklist", else: "Edit Checklist ##{@checklist.id}"}
    </.h1>

    <.form
      for={@form}
      id="checklist-form"
      phx-submit="save"
      phx-change="sync_checklist"
      class="space-y-4"
    >
      <div class="flex flex-col sm:flex-row gap-4">
        <div class="shrink-0">
          <.live_component
            module={MonthCalendar}
            id="observ_date_calendar"
            selected_date={@checklist.observ_date}
            hidden_name="checklist[observ_date]"
            errors={
              if show_field_error?(@form, :observ_date),
                do: Enum.map(@form[:observ_date].errors, &BaseComponents.translate_error/1),
                else: []
            }
          />
        </div>

        <div class="flex-1 space-y-3">
          <div class="flex flex-col sm:flex-row items-start gap-4">
            <div class="w-full sm:flex-1">
              <LocationAutocomplete.location_autocomplete
                id="location_search"
                label="Location"
                current_value={location_display(@checklist)}
                hidden_name="checklist[location_id]"
                hidden_value={@form[:location_id].value || ""}
                on_select_event="location_selected"
                scope={@current_scope}
                filter={Location.Filter.for_checklist_input()}
                errors={
                  if show_field_error?(@form, :location_id),
                    do: Enum.map(@form[:location_id].errors, &BaseComponents.translate_error/1),
                    else: []
                }
              />
            </div>
            <div class="sm:pt-7">
              <CoreComponents.input type="checkbox" field={@form[:motorless]} label="Motorless" />
            </div>
          </div>

          <div class="flex flex-col sm:flex-row flex-wrap gap-3 items-start">
            <div class="w-full sm:w-fit">
              <CoreComponents.input
                type="select"
                field={@form[:effort_type]}
                label="Effort Type"
                options={@effort_types}
                size={length(@effort_types)}
              />
            </div>
            <div class="grid grid-cols-2 lg:grid-cols-5 gap-3 flex-1">
              <CoreComponents.input
                type="time"
                field={@form[:start_time]}
                value={format_time(@form[:start_time].value)}
                label="Start Time"
              />
              <CoreComponents.input
                type="number"
                field={@form[:duration_minutes]}
                label="Duration (min)"
                step="1"
              />
              <CoreComponents.input
                type="number"
                field={@form[:distance_kms]}
                label="Distance (km)"
                step="0.1"
              />
              <CoreComponents.input
                type="number"
                field={@form[:area_acres]}
                label="Area (acres)"
                step="0.1"
              />

              <fieldset>
                <legend class="block text-sm font-medium font-header leading-6 text-zinc-800">
                  eBird Complete
                </legend>
                <div class="inline-flex overflow-hidden rounded-lg border border-gray-300">
                  <label class={[
                    "cursor-pointer px-5 py-1.5 text-sm font-semibold select-none",
                    "has-focus-visible:outline-2 has-focus-visible:-outline-offset-2 has-focus-visible:outline-blue-600",
                    @form[:ebird_complete].value == true && "bg-blue-100 text-blue-800",
                    @form[:ebird_complete].value != true && "bg-white text-gray-500 hover:bg-gray-50"
                  ]}>
                    <input
                      type="radio"
                      name="checklist[ebird_complete]"
                      value="true"
                      checked={@form[:ebird_complete].value == true}
                      class="sr-only"
                    /> YES
                  </label>
                  <label class={[
                    "cursor-pointer border-l border-gray-300 px-5 py-1.5 text-sm font-semibold select-none",
                    "has-focus-visible:outline-2 has-focus-visible:-outline-offset-2 has-focus-visible:outline-blue-600",
                    @form[:ebird_complete].value == false && "bg-blue-100 text-blue-800",
                    @form[:ebird_complete].value != false && "bg-white text-gray-500 hover:bg-gray-50"
                  ]}>
                    <input
                      type="radio"
                      name="checklist[ebird_complete]"
                      value="false"
                      checked={@form[:ebird_complete].value == false}
                      class="sr-only"
                    /> NO
                  </label>
                </div>
              </fieldset>
            </div>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <CoreComponents.input type="text" field={@form[:observers]} label="Observers" />
        <CoreComponents.input type="text" field={@form[:biotope]} label="Biotope" />
        <CoreComponents.input type="text" field={@form[:weather]} label="Weather" />
      </div>

      <CoreComponents.input type="textarea" field={@form[:notes]} label="Notes" rows="3" />

      <div class="pt-6 border-t border-gray-200">
        <h3 class="text-lg font-semibold text-zinc-800 mb-4">Observations</h3>

        <div class="space-y-4">
          <.inputs_for :let={obs_form} field={@form[:observations]}>
            <ObservationForm.observation_row
              obs_form={obs_form}
              obs={Enum.at(@checklist.observations, obs_form.index)}
              is_marked_for_deletion={MapSet.member?(@marked_for_deletion, obs_form.index)}
              current_user={@current_scope.current_user}
            />
          </.inputs_for>
        </div>

        <p :if={@checklist.observations == []} class="text-gray-500 italic py-4">
          No observations yet. Click "Add Observation" to start recording.
        </p>

        <button
          type="button"
          phx-click="add_observation"
          class="mt-4 inline-flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-semibold text-white hover:bg-blue-700"
        >
          <.icon name="hero-plus" class="w-4 h-4" /> Add Observation
        </button>
      </div>

      <div class="mt-6 rounded-lg border border-stone-200 bg-stone-50 p-4 space-y-2">
        <CoreComponents.input type="checkbox" field={@form[:resolved]} label="Resolved" />
        <p class="text-sm text-stone-500">
          Leave this unchecked to mark the checklist as unresolved when you intend to revisit and
          amend it later. You can filter your checklists to find unresolved ones at any time.
        </p>
      </div>

      <div class="flex flex-wrap items-center gap-4 pt-6">
        <button
          type="submit"
          phx-disable-with="Saving..."
          class="inline-flex items-center gap-2 rounded-lg bg-green-600 px-6 py-2 text-sm font-semibold text-white hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          Save Checklist
        </button>

        <.action_button navigate={~p"/my/checklists"} variant="secondary">Cancel</.action_button>
      </div>
    </.form>
    """
  end

  # Display helpers - get names from nested structs

  defp location_display(%{location: %Geo.Location{} = loc}),
    do: Geo.Location.long_name(:private, loc)

  defp location_display(_), do: ""

  # Callbacks for AutocompleteSearch components

  @impl true
  def handle_info({:calendar_select, "date_selected", %{"date" => date}}, socket) do
    checklist = socket.assigns.checklist
    updated_checklist = %{checklist | observ_date: date}

    {:noreply, assign_checklist(socket, updated_checklist)}
  end

  def handle_info({:autocomplete_select, "location_selected", %{"result" => result}}, socket) do
    checklist = socket.assigns.checklist
    updated_checklist = %{checklist | location_id: result.id, location: result}

    {:noreply, assign_checklist(socket, updated_checklist)}
  end

  def handle_info({:autocomplete_clear, "location_selected", _params}, socket) do
    checklist = socket.assigns.checklist
    updated_checklist = %{checklist | location_id: nil, location: nil}

    {:noreply, assign_checklist(socket, updated_checklist)}
  end

  def handle_info({:autocomplete_select, "taxon_selected", params}, socket) do
    index = params["index"]
    taxon = params["result"]
    checklist = socket.assigns.checklist

    updated_observations =
      checklist.observations
      |> Enum.with_index()
      |> Enum.map(fn {obs, idx} ->
        if idx == index do
          %{obs | taxon_key: taxon.key, taxon: taxon}
        else
          obs
        end
      end)

    updated_checklist = %{checklist | observations: updated_observations}

    {:noreply, assign_checklist(socket, updated_checklist)}
  end

  def handle_info({:autocomplete_clear, "taxon_selected", %{"index" => index}}, socket) do
    checklist = socket.assigns.checklist

    updated_observations =
      checklist.observations
      |> Enum.with_index()
      |> Enum.map(fn {obs, idx} ->
        if idx == index do
          %{obs | taxon_key: nil, taxon: nil}
        else
          obs
        end
      end)

    updated_checklist = %{checklist | observations: updated_observations}

    {:noreply, assign_checklist(socket, updated_checklist)}
  end

  defp do_save_checklist(:create, _checklist, checklist_params, user) do
    Birding.create_checklist(user, checklist_params)
  end

  defp do_save_checklist(:edit, checklist, checklist_params, user) do
    # Re-fetch the checklist from database to get the persisted state
    # This ensures Ecto can detect actual changes from form params
    db_checklist = Birding.fetch_checklist_for_edit(user, checklist.id)
    Birding.update_checklist(db_checklist, checklist_params)
  end

  defp show_field_error?(form, field_name) do
    # Show errors after form submission (when changeset has an action)
    form.source.action != nil && form[field_name].errors != []
  end

  # Existing observation (has ID) - mark for deletion
  defp do_remove_observation(socket, index, %{id: id}) when not is_nil(id) do
    {
      :noreply,
      socket
      |> assign(:marked_for_deletion, MapSet.put(socket.assigns.marked_for_deletion, index))
    }
  end

  # New observation (no ID) - remove immediately
  defp do_remove_observation(socket, index, _observation) do
    checklist = socket.assigns.checklist

    new_observations =
      checklist.observations
      |> Enum.with_index()
      |> Enum.reject(fn {_obs, idx} -> idx == index end)
      |> Enum.map(fn {obs, _idx} -> obs end)

    updated_checklist = %{checklist | observations: new_observations}

    # Re-index marked_for_deletion after removing an observation
    new_marked_for_deletion =
      socket.assigns.marked_for_deletion
      |> Enum.reject(fn idx -> idx == index end)
      |> Enum.map(fn idx ->
        if idx > index, do: idx - 1, else: idx
      end)
      |> MapSet.new()

    {
      :noreply,
      socket
      |> assign(:marked_for_deletion, new_marked_for_deletion)
      |> assign_checklist(updated_checklist)
    }
  end

  # Merge form params into checklist struct, preserving nested structs (taxon, location)
  defp merge_params_into_checklist(checklist, params) do
    observations = merge_observation_params(checklist.observations, params["observations"])

    # Preserve location_id from checklist if not in params (select_location sets it directly)
    location_id =
      case params["location_id"] do
        nil -> checklist.location_id
        "" -> checklist.location_id
        id_str -> String.to_integer(id_str)
      end

    %{
      checklist
      | observ_date: parse_date(params["observ_date"]),
        start_time: parse_time(params["start_time"]),
        effort_type: params["effort_type"],
        location_id: location_id,
        duration_minutes: parse_int(params["duration_minutes"]),
        distance_kms: parse_float(params["distance_kms"]),
        area_acres: parse_float(params["area_acres"]),
        biotope: params["biotope"],
        weather: params["weather"],
        observers: params["observers"],
        ebird_complete: parse_tristate_bool(params["ebird_complete"]),
        notes: params["notes"],
        motorless: params["motorless"] == "true",
        resolved: params["resolved"] == "true",
        observations: observations
    }
  end

  defp merge_observation_params(observations, nil), do: observations

  defp merge_observation_params(observations, obs_params) when is_map(obs_params) do
    observations
    |> Enum.with_index()
    |> Enum.map(fn {obs, idx} -> merge_single_observation(obs, obs_params, idx) end)
  end

  defp merge_single_observation(obs, obs_params, idx) do
    case Map.get(obs_params, to_string(idx)) do
      nil ->
        obs

      obs_param ->
        %{
          obs
          | quantity: obs_param["quantity"],
            voice: obs_param["voice"] == "true",
            notes: obs_param["notes"],
            private_notes: obs_param["private_notes"],
            hidden: obs_param["hidden"] == "true",
            unreported: obs_param["unreported"] == "true"
        }
    end
  end

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil
  defp parse_date(str), do: Date.from_iso8601!(str)

  defp parse_time(nil), do: nil
  defp parse_time(""), do: nil

  # The time input submits either "HH:MM" (Chrome's default) or "HH:MM:SS"
  # (e.g. when an existing checklist's start_time is rendered back with seconds on
  # edit). Normalize to a full ISO time before parsing rather than blindly
  # appending ":00", which would corrupt an already-complete "HH:MM:SS" value.
  defp parse_time(str) do
    normalized = if String.length(str) == 5, do: str <> ":00", else: str

    case Time.from_iso8601(normalized) do
      {:ok, time} -> time
      {:error, _} -> nil
    end
  end

  defp parse_tristate_bool("true"), do: true
  defp parse_tristate_bool("false"), do: false
  defp parse_tristate_bool(_), do: nil

  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil
  defp parse_int(str), do: String.to_integer(str)

  defp parse_float(nil), do: nil
  defp parse_float(""), do: nil
  defp parse_float(str), do: String.to_float(str)
end
