defmodule KjogviWeb.Live.My.Cards.ObservationForm do
  @moduledoc """
  Function components for rendering observation rows within the card form.
  """

  use KjogviWeb, :html

  alias KjogviWeb.CoreComponents

  attr :obs_form, :map, required: true
  attr :obs, :map, required: true
  attr :is_marked_for_deletion, :boolean, required: true
  attr :taxon_search_results, :list, required: true
  attr :editing_observation_index, :integer, required: true

  def observation_row(assigns) do
    ~H"""
    <div class={[
      "p-4 border rounded-lg",
      if(@is_marked_for_deletion,
        do: "border-red-300 bg-red-50 opacity-60",
        else: "border-gray-200 bg-white"
      )
    ]}>
      <%!-- Hidden input to track observation order --%>
      <input type="hidden" name="card[observations_order][]" value={@obs_form.index} />

      <%!-- Hidden input to mark for deletion --%>
      <input
        :if={@is_marked_for_deletion}
        type="hidden"
        name="card[observations_drop][]"
        value={@obs_form.index}
      />

      <%= if @is_marked_for_deletion do %>
        <div class="flex items-center justify-between">
          <div class="flex-1 line-through text-gray-500">
            <span class="font-medium">
              {taxon_display(@obs)}
            </span>
            <span :if={@obs_form[:quantity].value} class="ml-2">
              × {@obs_form[:quantity].value}
            </span>
          </div>
          <button
            type="button"
            phx-click="restore_observation"
            phx-value-index={@obs_form.index}
            class="inline-flex items-center gap-2 rounded-lg bg-green-100 px-3 py-2 text-sm font-semibold text-green-700 hover:bg-green-200"
          >
            <.icon name="hero-arrow-uturn-left" class="w-4 h-4" /> Restore
          </button>
        </div>
      <% else %>
        <div class="grid grid-cols-1 gap-4 sm:grid-cols-5">
          <.autocomplete_input
            label="Taxon"
            id={"card_observations_#{@obs_form.index}_taxon_search"}
            placeholder="Search and select taxon..."
            value={taxon_display(@obs)}
            search_event={"search_taxa:#{@obs_form.index}"}
            focus_event={"focus_taxon_field:#{@obs_form.index}"}
            hidden_name={"card[observations][#{@obs_form.index}][taxon_key]"}
            hidden_value={@obs_form[:taxon_key].value || ""}
            errors={
              if show_field_error?(@obs_form, :taxon_key),
                do: Enum.map(@obs_form[:taxon_key].errors, &CoreComponents.translate_error/1),
                else: []
            }
            show_results={
              !Enum.empty?(@taxon_search_results) and @editing_observation_index == @obs_form.index
            }
          >
            <:results>
              <.autocomplete_option
                :for={result <- @taxon_search_results}
                phx-click={"select_taxon:#{@obs_form.index}"}
                phx-value-code={result.key}
              >
                <div class="font-medium">{result.name_en}</div>
                <div class="text-xs text-gray-500 italic">{result.name_sci}</div>
              </.autocomplete_option>
            </:results>
          </.autocomplete_input>

          <CoreComponents.input
            type="text"
            field={@obs_form[:quantity]}
            label="Quantity"
            placeholder="e.g., 1, 2-3, 10+"
          />

          <div class="flex items-end gap-1">
            <div class="flex-1">
              <label class="block text-xs font-semibold leading-6 text-zinc-800">
                Heard only
              </label>
              <CoreComponents.input type="checkbox" field={@obs_form[:voice]} class="mt-1" />
            </div>
            <div class="flex-1">
              <label class="block text-xs font-semibold leading-6 text-zinc-800">
                Hidden
              </label>
              <CoreComponents.input type="checkbox" field={@obs_form[:hidden]} class="mt-1" />
            </div>
            <div class="flex-1">
              <label class="block text-xs font-semibold leading-6 text-zinc-800">
                Unreported
              </label>
              <CoreComponents.input
                type="checkbox"
                field={@obs_form[:unreported]}
                class="mt-1"
              />
            </div>
          </div>

          <button
            type="button"
            phx-click="remove_observation"
            phx-value-index={@obs_form.index}
            class="inline-flex items-center gap-2 rounded-lg bg-red-100 px-3 py-2 text-sm font-semibold text-red-700 hover:bg-red-200 h-fit"
          >
            <.icon name="hero-trash" class="w-4 h-4" /> Remove
          </button>
        </div>

        <div class="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2">
          <CoreComponents.input
            type="text"
            field={@obs_form[:notes]}
            label="Notes"
            placeholder="Public notes"
          />

          <CoreComponents.input
            type="text"
            field={@obs_form[:private_notes]}
            label="Private Notes"
            placeholder="Private notes"
          />
        </div>
      <% end %>
    </div>
    """
  end

  defp taxon_display(%{taxon: %{name_en: name_en, name_sci: name_sci}})
       when not is_nil(name_en),
       do: "#{name_en} #{name_sci}"

  defp taxon_display(%{taxon_key: key}) when not is_nil(key), do: key
  defp taxon_display(_), do: ""

  defp show_field_error?(form, field_name) do
    form.source.action != nil && form[field_name].errors != []
  end
end
