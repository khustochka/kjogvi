defmodule KjogviWeb.Live.My.Cards.Form do
  @moduledoc """
  LiveView for creating and editing cards.

  Uses the card struct as single source of truth. The card holds:
  - All field values
  - Nested observations with taxon structs (for display names)
  - Location struct (for display name)

  The form is derived from the card via `to_form(Birding.change_card(card))`.
  """

  use KjogviWeb, :live_view

  alias Kjogvi.Birding
  alias Kjogvi.Geo
  alias Kjogvi.Search
  alias KjogviWeb.Live.My.Cards.ObservationForm

  @impl true
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> assign(:marked_for_deletion, MapSet.new())
    }
  end

  @impl true
  def handle_params(%{"id" => id}, _url, %{assigns: assigns} = socket) do
    card = Birding.fetch_card_for_edit(assigns.current_scope.user, id)
    # Preload taxa on observations for display
    observations_with_taxa = Birding.preload_taxa_and_species(card.observations)
    card = %{card | observations: observations_with_taxa}

    {
      :noreply,
      socket
      |> assign(:page_title, "Edit Card ##{card.id}")
      |> assign(:action, :edit)
      |> assign_card(card)
    }
  end

  def handle_params(_params, _url, %{assigns: assigns} = socket) do
    card = Birding.new_card(assigns.current_scope.user)
    card = %{card | observations: []}

    {
      :noreply,
      socket
      |> assign(:page_title, "New Card")
      |> assign(:action, :create)
      |> assign_card(card)
    }
  end

  # Helper to update card and derive form
  defp assign_card(socket, card) do
    socket
    |> assign(:card, card)
    |> assign(:form, to_form(Birding.change_card(card)))
  end

  @impl true
  def handle_event("add_observation", _params, socket) do
    card = socket.assigns.card

    new_observation = %Kjogvi.Birding.Observation{
      id: nil,
      card_id: nil,
      taxon_key: nil,
      taxon: nil,
      quantity: nil,
      voice: false,
      notes: nil,
      private_notes: nil,
      hidden: false,
      unreported: false
    }

    updated_card = %{card | observations: card.observations ++ [new_observation]}

    {:noreply, assign_card(socket, updated_card)}
  end

  def handle_event("remove_observation", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    observation = Enum.at(socket.assigns.card.observations, index)

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

  def handle_event("validate", %{"card" => card_params}, socket) do
    # Sync form field values to card struct
    card = socket.assigns.card
    updated_card = merge_params_into_card(card, card_params)
    changeset = Birding.change_card(updated_card)

    {:noreply, assign(socket, :card, updated_card) |> assign(:form, to_form(changeset))}
  end

  def handle_event("save", %{"card" => card_params}, %{assigns: assigns} = socket) do
    case do_save_card(assigns.action, assigns.card, card_params, assigns.current_scope.user) do
      {:ok, card} ->
        {
          :noreply,
          socket
          |> put_flash(:info, "Card saved successfully")
          |> push_navigate(to: ~p"/my/cards/#{card.id}")
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
    effort_types = Kjogvi.Birding.Card.effort_types()
    assigns = assign(assigns, :effort_types, effort_types)

    ~H"""
    <CoreComponents.header>
      {if @action == :create, do: "New Card", else: "Edit Card ##{@card.id}"}
    </CoreComponents.header>

    <form phx-submit="save" phx-change="validate" phx-debounce="200" class="space-y-6">
      <div class="grid grid-cols-1 gap-6 sm:grid-cols-3">
        <CoreComponents.input type="date" field={@form[:observ_date]} label="Observation Date" />

        <CoreComponents.input type="time" field={@form[:start_time]} label="Start Time" />

        <CoreComponents.input
          type="select"
          field={@form[:effort_type]}
          label="Effort Type"
          options={@effort_types}
          prompt="Select effort type..."
        />
      </div>
      <div class="grid grid-cols-1 gap-6 sm:grid-cols-3">
        <.live_component
          module={KjogviWeb.Live.Components.AutocompleteSearch}
          id="location_search"
          label="Location"
          placeholder="Search and select location..."
          current_value={location_display(@card)}
          hidden_name="card[location_id]"
          hidden_value={@form[:location_id].value || ""}
          search_fn={&Search.Location.search_locations/1}
          on_select_event="location_selected"
          errors={
            if show_field_error?(@form, :location_id),
              do: Enum.map(@form[:location_id].errors, &CoreComponents.translate_error/1),
              else: []
          }
        />

        <CoreComponents.input type="text" field={@form[:observers]} label="Observers" />

        <div>
          <label class="block text-sm font-semibold leading-6 text-zinc-800">
            Motorless
          </label>
          <CoreComponents.input type="checkbox" field={@form[:motorless]} class="mt-2" />
        </div>
      </div>

      <div class="grid grid-cols-1 gap-6 sm:grid-cols-3">
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
      </div>

      <div class="grid grid-cols-1 gap-6 sm:grid-cols-3">
        <CoreComponents.input type="text" field={@form[:biotope]} label="Biotope" />

        <CoreComponents.input type="text" field={@form[:weather]} label="Weather" />
      </div>

      <CoreComponents.input type="textarea" field={@form[:notes]} label="Notes" rows="4" />

      <div class="pt-6 border-t border-gray-200">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg font-semibold text-zinc-800">Observations</h3>
          <button
            type="button"
            phx-click="add_observation"
            class="inline-flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-semibold text-white hover:bg-blue-700"
          >
            <.icon name="hero-plus" class="w-4 h-4" /> Add Observation
          </button>
        </div>

        <div class="space-y-4">
          <.inputs_for :let={obs_form} field={@form[:observations]}>
            <ObservationForm.observation_row
              obs_form={obs_form}
              obs={Enum.at(@card.observations, obs_form.index)}
              is_marked_for_deletion={MapSet.member?(@marked_for_deletion, obs_form.index)}
              current_user={@current_scope.user}
            />
          </.inputs_for>
        </div>

        <p :if={@card.observations == []} class="text-gray-500 italic py-4">
          No observations yet. Click "Add Observation" to start recording.
        </p>
      </div>

      <div class="flex gap-4 pt-6">
        <button
          type="submit"
          class="inline-flex items-center gap-2 rounded-lg bg-green-600 px-6 py-2 text-sm font-semibold text-white hover:bg-green-700"
        >
          <.icon name="hero-check" class="w-4 h-4" /> Save Card
        </button>

        <.link
          navigate={~p"/my/cards"}
          class="inline-flex items-center gap-2 rounded-lg bg-gray-200 px-6 py-2 text-sm font-semibold text-gray-800 hover:bg-gray-300"
        >
          Cancel
        </.link>
      </div>
    </form>
    """
  end

  # Display helpers - get names from nested structs

  # On edit load, the location is a full struct with preloaded associations,
  # so we compute long_name from them. After select_location, it's a minimal
  # struct where name_en already holds the long name from search results.
  defp location_display(%{location: %Geo.Location{} = loc}) do
    if Ecto.assoc_loaded?(loc.cached_city) do
      Geo.Location.long_name(loc)
    else
      # Name_en here is actually the long name from search results
      loc.name_en || ""
    end
  end

  defp location_display(_), do: ""

  # Callbacks for AutocompleteSearch components

  @impl true
  def handle_info({:autocomplete_select, "location_selected", %{"result" => result}}, socket) do
    location_struct = %Geo.Location{
      id: result.id,
      name_en: result.long_name
    }

    card = socket.assigns.card
    updated_card = %{card | location_id: result.id, location: location_struct}

    {:noreply, assign_card(socket, updated_card)}
  end

  def handle_info({:autocomplete_select, "taxon_selected", params}, socket) do
    index = params["index"]
    taxon = params["result"]
    card = socket.assigns.card

    updated_observations =
      card.observations
      |> Enum.with_index()
      |> Enum.map(fn {obs, idx} ->
        if idx == index do
          %{obs | taxon_key: taxon.key, taxon: taxon}
        else
          obs
        end
      end)

    updated_card = %{card | observations: updated_observations}

    {:noreply, assign_card(socket, updated_card)}
  end

  defp do_save_card(:create, _card, card_params, user) do
    Birding.create_card(user, card_params)
  end

  defp do_save_card(:edit, card, card_params, user) do
    # Re-fetch the card from database to get the persisted state
    # This ensures Ecto can detect actual changes from form params
    db_card = Birding.fetch_card_for_edit(user, card.id)
    Birding.update_card(db_card, card_params)
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
    card = socket.assigns.card

    new_observations =
      card.observations
      |> Enum.with_index()
      |> Enum.reject(fn {_obs, idx} -> idx == index end)
      |> Enum.map(fn {obs, _idx} -> obs end)

    updated_card = %{card | observations: new_observations}

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
      |> assign_card(updated_card)
    }
  end

  # Merge form params into card struct, preserving nested structs (taxon, location)
  defp merge_params_into_card(card, params) do
    observations = merge_observation_params(card.observations, params["observations"])

    # Preserve location_id from card if not in params (select_location sets it directly)
    location_id =
      case params["location_id"] do
        nil -> card.location_id
        "" -> card.location_id
        id_str -> String.to_integer(id_str)
      end

    %{
      card
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
        notes: params["notes"],
        motorless: params["motorless"] == "true",
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
  defp parse_time(str), do: Time.from_iso8601!(str <> ":00")

  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil
  defp parse_int(str), do: String.to_integer(str)

  defp parse_float(nil), do: nil
  defp parse_float(""), do: nil
  defp parse_float(str), do: String.to_float(str)
end
