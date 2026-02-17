defmodule KjogviWeb.Live.My.Cards.ObservationForm do
  @moduledoc """
  Function components for rendering observation rows within the card form.
  """

  use KjogviWeb, :html

  alias KjogviWeb.CoreComponents

  attr :obs_form, :map, required: true
  attr :obs, :map, required: true
  attr :is_marked_for_deletion, :boolean, required: true
  attr :current_user, :map, required: true

  def observation_row(assigns) do
    ~H"""
    <div class={[
      "rounded-lg",
      if(@is_marked_for_deletion,
        do: "border-red-300 bg-red-50 opacity-60 p-4 border",
        else: "border-gray-200 bg-white p-4 border lg:border-0 lg:p-0"
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
              {@obs_form[:id].value}
            </span>
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
            class="inline-flex items-center gap-2 rounded-lg bg-green-100 px-3 py-2 text-sm font-semibold text-green-700 hover:bg-green-200 border border-green-500"
          >
            <.icon name="hero-arrow-uturn-left" class="w-4 h-4" /> Restore
          </button>
        </div>
      <% else %>
        <div class="grid grid-cols-[1fr_auto] gap-x-3 gap-y-3 lg:grid-cols-[minmax(10rem,1fr)_8rem_minmax(6rem,0.8fr)_minmax(6rem,0.8fr)_auto_auto] lg:items-end">
          <div class="col-span-2 lg:col-span-1">
            <.live_component
              module={KjogviWeb.Live.Components.AutocompleteSearch}
              id={"taxon_search_#{@obs_form.index}"}
              label={(@obs_form[:id].value && "Observation ##{@obs_form[:id].value}") || "Taxon"}
              placeholder="Search and select taxon..."
              current_value={taxon_display(@obs)}
              hidden_name={"card[observations][#{@obs_form.index}][taxon_key]"}
              hidden_value={@obs_form[:taxon_key].value || ""}
              search_fn={fn query -> Kjogvi.Search.Taxon.search_taxa(query, @current_user) end}
              on_select_event="taxon_selected"
              on_select_params={%{"index" => @obs_form.index}}
              compact={true}
              errors={
                if show_field_error?(@obs_form, :taxon_key),
                  do: Enum.map(@obs_form[:taxon_key].errors, &CoreComponents.translate_error/1),
                  else: []
              }
            />
          </div>

          <div class="col-span-2 lg:col-span-1">
            <.compact_input field={@obs_form[:quantity]} label="Quantity" />
          </div>

          <div class="col-span-2 lg:col-span-1">
            <.compact_input field={@obs_form[:notes]} label="Notes" />
          </div>

          <div class="col-span-2 lg:col-span-1">
            <.compact_input field={@obs_form[:private_notes]} label="Private notes" />
          </div>

          <div class="flex lg:flex-col gap-2 lg:gap-0.5 items-end lg:items-start lg:justify-end">
            <label
              for={@obs_form[:voice].id}
              class="inline-flex items-center gap-1 text-xs font-semibold text-zinc-800 whitespace-nowrap"
            >
              <CoreComponents.input type="checkbox" field={@obs_form[:voice]} /> Heard
            </label>
            <label
              for={@obs_form[:hidden].id}
              class="inline-flex items-center gap-1 text-xs font-semibold text-zinc-800 whitespace-nowrap"
            >
              <CoreComponents.input type="checkbox" field={@obs_form[:hidden]} /> Hidden
            </label>
            <label
              for={@obs_form[:unreported].id}
              class="inline-flex items-center gap-1 text-xs font-semibold text-zinc-800 whitespace-nowrap"
            >
              <CoreComponents.input type="checkbox" field={@obs_form[:unreported]} /> Unreported
            </label>
          </div>

          <button
            type="button"
            phx-click="remove_observation"
            phx-value-index={@obs_form.index}
            aria-label="Remove observation"
            title="Remove observation"
            class="rounded-lg bg-red-100 px-2 pb-2 pt-1 text-red-700 hover:bg-red-200 self-end mb-0.5"
          >
            <%= if @obs_form[:id].value do %>
              <.icon name="hero-trash" class="w-4 h-4" />
            <% else %>
              <.icon name="hero-x-mark" class="w-4 h-4" />
            <% end %>
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, required: true
  attr :rest, :global, include: ~w(placeholder)

  defp compact_input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns =
      assigns
      |> assign(:id, field.id)
      |> assign(:name, field.name)
      |> assign(:value, field.value)
      |> assign(:errors, Enum.map(errors, &CoreComponents.translate_error/1))

    ~H"""
    <div>
      <label for={@id} class="block text-sm font-semibold leading-6 text-zinc-800">
        {@label}
      </label>
      <input
        type="text"
        id={@id}
        name={@name}
        value={Phoenix.HTML.Form.normalize_value("text", @value)}
        class={[
          "block w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6 px-2 py-1",
          @errors == [] && "border-zinc-300 focus:border-zinc-400",
          @errors != [] && "border-rose-400 focus:border-rose-400"
        ]}
        {@rest}
      />
      <CoreComponents.error :for={msg <- @errors}>{msg}</CoreComponents.error>
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
