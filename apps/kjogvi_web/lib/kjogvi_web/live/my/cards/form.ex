defmodule KjogviWeb.Live.My.Cards.Form do
  @moduledoc false

  use KjogviWeb, :live_view

  alias Kjogvi.Birding
  alias Kjogvi.Geo
  alias Kjogvi.Search

  @impl true
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> assign(:taxon_search_results, [])
      |> assign(:location_search_results, [])
      |> assign(:editing_observation_index, nil)
      |> assign(:location_input_value, "")
      |> assign(:taxon_display_values, %{})
    }
  end

  @impl true
  def handle_params(%{"id" => id}, _url, %{assigns: assigns} = socket) do
    card = Birding.fetch_card_for_edit(assigns.current_scope.user, id)
    observations_with_taxa = Birding.preload_taxa_and_species(card.observations)
    taxon_display_values = build_taxon_display_values(observations_with_taxa)

    {
      :noreply,
      socket
      |> assign(:page_title, "Edit Card ##{card.id}")
      |> assign(:action, :edit)
      |> assign(:card, card)
      |> assign(:location_input_value, Geo.Location.long_name(card.location))
      |> assign(:form, to_form(Birding.change_card(card)))
      |> assign(:taxon_display_values, taxon_display_values)
    }
  end

  def handle_params(_params, _url, %{assigns: assigns} = socket) do
    card = Birding.new_card(assigns.current_scope.user)

    {
      :noreply,
      socket
      |> assign(:page_title, "New Card")
      |> assign(:action, :create)
      |> assign(:card, card)
      |> assign(:form, to_form(Birding.change_card(card)))
    }
  end

  @impl true
  def handle_event("add_observation", _params, socket) do
    form = socket.assigns.form

    new_observation = %Kjogvi.Birding.Observation{
      id: nil,
      card_id: nil,
      taxon_key: nil,
      quantity: nil,
      voice: false,
      notes: nil,
      private_notes: nil,
      hidden: false,
      unreported: false
    }

    new_observations = form.data.observations ++ [new_observation]
    card = %{form.data | observations: new_observations}
    changeset = Birding.change_card(card)

    {
      :noreply,
      socket
      |> assign(:form, to_form(changeset))
    }
  end

  def handle_event("remove_observation", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    form = socket.assigns.form

    new_observations =
      form.data.observations
      |> Enum.with_index()
      |> Enum.filter(fn {_obs, idx} -> idx != index end)
      |> Enum.map(fn {obs, _idx} -> obs end)

    card = %{form.data | observations: new_observations}

    # Re-index taxon_display_values after removing an observation
    new_taxon_display_values =
      socket.assigns.taxon_display_values
      |> Enum.reject(fn {idx, _} -> idx == index end)
      |> Enum.map(fn {idx, val} ->
        if idx > index, do: {idx - 1, val}, else: {idx, val}
      end)
      |> Map.new()

    {
      :noreply,
      socket
      |> assign(:form, to_form(Birding.change_card(card)))
      |> assign(:taxon_display_values, new_taxon_display_values)
    }
  end

  def handle_event("search_taxa:" <> index_str, %{"value" => query}, %{assigns: assigns} = socket) do
    index = String.to_integer(index_str)
    results = Search.Taxon.search_taxa(query, assigns.current_scope.user)

    {
      :noreply,
      socket
      |> assign(:taxon_search_results, results)
      |> assign(:editing_observation_index, index)
    }
  end

  def handle_event("focus_taxon_field:" <> index_str, _params, socket) do
    index = String.to_integer(index_str)

    {
      :noreply,
      socket
      |> assign(:editing_observation_index, index)
    }
  end

  def handle_event("search_locations", %{"value" => query}, socket) do
    results = Search.Location.search_locations(query)

    {
      :noreply,
      socket
      |> assign(:location_search_results, results)
      |> assign(:location_input_value, query)
    }
  end

  def handle_event(
        "select_location",
        %{"id" => location_id_str, "name" => name},
        %{assigns: assigns} = socket
      ) do
    location_id = String.to_integer(location_id_str)
    form = assigns.form
    card = form.data

    updated_card = %{card | location_id: location_id}
    changeset = Birding.change_card(updated_card)

    {
      :noreply,
      socket
      |> assign(:location_search_results, [])
      |> assign(:location_input_value, name)
      |> assign(:form, to_form(changeset))
    }
  end

  def handle_event(
        "select_taxon:" <> index_str,
        %{"code" => taxon_code, "name" => name},
        %{assigns: assigns} = socket
      ) do
    index = String.to_integer(index_str)
    form = assigns.form
    observations = form.data.observations || []

    updated_observations =
      observations
      |> Enum.with_index()
      |> Enum.map(fn {obs, idx} ->
        if idx == index do
          %{obs | taxon_key: taxon_code}
        else
          obs
        end
      end)

    card = %{form.data | observations: updated_observations}
    changeset = Birding.change_card(card)

    {
      :noreply,
      socket
      |> assign(:taxon_search_results, [])
      |> assign(:form, to_form(changeset))
      |> assign(:editing_observation_index, nil)
      |> assign(:taxon_display_values, Map.put(assigns.taxon_display_values, index, name))
    }
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

    <form phx-submit="save" class="space-y-6">
      <div class="grid grid-cols-1 gap-6 sm:grid-cols-3">
        <CoreComponents.input
          type="date"
          field={@form[:observ_date]}
          label="Observation Date"
        />

        <CoreComponents.input
          type="time"
          field={@form[:start_time]}
          label="Start Time"
        />

        <CoreComponents.input
          type="select"
          field={@form[:effort_type]}
          label="Effort Type"
          options={@effort_types}
          prompt="Select effort type..."
        />
      </div>
      <div class="grid grid-cols-1 gap-6 sm:grid-cols-3">
        <div>
          <label class="block text-sm font-semibold leading-6 text-zinc-800">Location</label>
          <div class="relative mt-2">
            <input
              type="search"
              id="card_location_search"
              placeholder="Search and select location..."
              phx-keyup="search_locations"
              autocomplete="off"
              value={@location_input_value}
              class="mt-0 block w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6 border-zinc-300 focus:border-zinc-400"
            />
            <input
              type="hidden"
              name="card[location_id]"
              id="card_location_id"
              value={@form[:location_id].value || ""}
            />

            <%= if !Enum.empty?(@location_search_results) do %>
              <div class="absolute top-full left-0 right-0 z-10 mt-1 border border-gray-300 rounded-lg shadow-lg max-h-48 overflow-y-auto bg-white">
                <%= for result <- @location_search_results do %>
                  <div
                    class="px-3 py-2 cursor-pointer border-b last:border-b-0 text-sm hover:bg-blue-50"
                    phx-click="select_location"
                    phx-value-id={result.id}
                    phx-value-name={result.name}
                  >
                    {result.name}
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <CoreComponents.input
          type="text"
          field={@form[:observers]}
          label="Observers"
        />

        <div>
          <label class="block text-sm font-semibold leading-6 text-zinc-800">
            Motorless
          </label>
          <CoreComponents.input
            type="checkbox"
            field={@form[:motorless]}
            class="mt-2"
          />
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
        <CoreComponents.input
          type="text"
          field={@form[:biotope]}
          label="Biotope"
        />

        <CoreComponents.input
          type="text"
          field={@form[:weather]}
          label="Weather"
        />
      </div>

      <CoreComponents.input
        type="textarea"
        field={@form[:notes]}
        label="Notes"
        rows="4"
      />

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
            <div class="p-4 border border-gray-200 rounded-lg bg-white">
              <div class="grid grid-cols-1 gap-4 sm:grid-cols-5">
                <div>
                  <label class="block text-sm font-semibold leading-6 text-zinc-800">Taxon</label>
                  <div class="relative mt-2">
                    <input
                      type="search"
                      id={"card_observations_#{obs_form.index}_taxon_search"}
                      placeholder="Search and select taxon..."
                      phx-keyup={"search_taxa:#{obs_form.index}"}
                      phx-focus={"focus_taxon_field:#{obs_form.index}"}
                      autocomplete="off"
                      value={
                        Map.get(
                          @taxon_display_values,
                          obs_form.index,
                          obs_form[:taxon_key].value || ""
                        )
                      }
                      class="mt-0 block w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6 border-zinc-300 focus:border-zinc-400"
                    />

                    <input
                      type="hidden"
                      name={"card[observations][#{obs_form.index}][taxon_key]"}
                      value={obs_form[:taxon_key].value || ""}
                    />

                    <%= if !Enum.empty?(@taxon_search_results) and @editing_observation_index == obs_form.index do %>
                      <div class="absolute top-full left-0 right-0 z-10 mt-1 border border-gray-300 rounded-lg shadow-lg max-h-40 overflow-y-auto bg-white">
                        <%= for result <- @taxon_search_results do %>
                          <div
                            class="px-3 py-2 cursor-pointer border-b last:border-b-0 text-sm hover:bg-blue-50"
                            phx-click={"select_taxon:#{obs_form.index}"}
                            phx-value-code={result.key}
                            phx-value-name={"#{result.name_en} #{result.name_sci}"}
                          >
                            <div class="font-medium">{result.name_en}</div>
                            <div class="text-xs text-gray-500 italic">{result.name_sci}</div>
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                </div>

                <CoreComponents.input
                  type="text"
                  field={obs_form[:quantity]}
                  label="Quantity"
                  placeholder="e.g., 1, 2-3, 10+"
                />

                <div class="flex items-end gap-1">
                  <div class="flex-1">
                    <label class="block text-xs font-semibold leading-6 text-zinc-800">
                      Heard only
                    </label>
                    <CoreComponents.input
                      type="checkbox"
                      field={obs_form[:voice]}
                      class="mt-1"
                    />
                  </div>
                  <div class="flex-1">
                    <label class="block text-xs font-semibold leading-6 text-zinc-800">
                      Hidden
                    </label>
                    <CoreComponents.input
                      type="checkbox"
                      field={obs_form[:hidden]}
                      class="mt-1"
                    />
                  </div>
                  <div class="flex-1">
                    <label class="block text-xs font-semibold leading-6 text-zinc-800">
                      Unreported
                    </label>
                    <CoreComponents.input
                      type="checkbox"
                      field={obs_form[:unreported]}
                      class="mt-1"
                    />
                  </div>
                </div>

                <button
                  type="button"
                  phx-click="remove_observation"
                  phx-value-index={obs_form.index}
                  class="inline-flex items-center gap-2 rounded-lg bg-red-100 px-3 py-2 text-sm font-semibold text-red-700 hover:bg-red-200 h-fit"
                >
                  <.icon name="hero-trash" class="w-4 h-4" /> Remove
                </button>
              </div>

              <div class="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2">
                <CoreComponents.input
                  type="text"
                  field={obs_form[:notes]}
                  label="Notes"
                  placeholder="Public notes"
                />

                <CoreComponents.input
                  type="text"
                  field={obs_form[:private_notes]}
                  label="Private Notes"
                  placeholder="Private notes"
                />
              </div>
            </div>
          </.inputs_for>
        </div>

        <p :if={empty_observations?(@form.data.observations)} class="text-gray-500 italic py-4">
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

  defp do_save_card(:create, _card, card_params, user) do
    Birding.create_card(user, card_params)
  end

  defp do_save_card(:edit, card, card_params, _user) do
    Birding.update_card(card, card_params)
  end

  defp empty_observations?(%Ecto.Association.NotLoaded{}), do: true

  defp empty_observations?(observations) when is_list(observations),
    do: Enum.empty?(observations)

  defp empty_observations?(_), do: true

  defp build_taxon_display_values(observations_with_taxa) do
    observations_with_taxa
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {obs, index}, acc ->
      if obs.taxon do
        display_name = "#{obs.taxon.name_en} #{obs.taxon.name_sci}"
        Map.put(acc, index, display_name)
      else
        acc
      end
    end)
  end
end
