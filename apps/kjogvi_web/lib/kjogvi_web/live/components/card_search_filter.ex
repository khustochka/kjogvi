defmodule KjogviWeb.Live.Components.CardSearchFilter do
  @moduledoc """
  Search/filter panel for the cards index.

  A **function** component (not a LiveComponent) by deliberate design: the
  taxon/location pickers it embeds are `Autocomplete` LiveComponents which
  deliver their selection via `send(self(), {:autocomplete_select, ...})` to
  the *host LiveView*, not to an enclosing component. The panel therefore owns
  no state of its own — the host LiveView holds the current
  `CardSearch.Filter`, feeds it in here for display, and handles the events
  this panel emits.

  ## Events emitted to the host

    * `phx-change="filter_change"` / `phx-submit="filter_search"` on the form,
      carrying the non-autocomplete fields (`date`, `include_subregions`,
      `voice`, `exclude_subspecies`, `hidden`).
    * `{:autocomplete_select, "filter_taxon", %{"result" => taxon}}` and
      `{:autocomplete_clear, "filter_taxon", _}` for the taxon field.
    * `{:autocomplete_select, "filter_location", %{"result" => location}}` and
      `{:autocomplete_clear, "filter_location", _}` for the location field.
    * `phx-click="filter_reset"` on the reset control.
  """

  use KjogviWeb, :html

  alias Kjogvi.Birding.CardSearch.Filter
  alias Kjogvi.Geo
  alias KjogviWeb.Live.Components.LocationAutocomplete
  alias KjogviWeb.Live.Components.TaxonAutocomplete

  attr :id, :string, default: "card-search-filter"
  attr :filter, Filter, required: true
  attr :user, :map, required: true
  attr :scope, Kjogvi.Scope, required: true

  attr :taxon_label, :string,
    default: "",
    doc: "display text for the currently selected taxon, if any"

  def card_search_filter(assigns) do
    ~H"""
    <form
      id={@id}
      phx-change="filter_change"
      phx-submit="filter_search"
      class="mb-6 rounded-xl border border-indigo-200 bg-indigo-50/60 p-4 sm:p-5"
    >
      <div class="grid grid-cols-1 gap-x-5 gap-y-4 sm:grid-cols-2 lg:grid-cols-[repeat(3,minmax(0,1fr))_auto_auto]">
        <%!-- Taxon --%>
        <div>
          <label
            for={"#{@id}-taxon"}
            class="block text-sm font-medium font-header leading-6 text-indigo-900"
          >Taxon</label>
          <div>
            <TaxonAutocomplete.taxon_autocomplete
              id={"#{@id}-taxon"}
              user={@user}
              current_value={@taxon_label}
              hidden_name="filter[taxon_key]"
              hidden_value={@filter.taxon_key || ""}
              placeholder=""
              on_select_event="filter_taxon"
              compact
            />
          </div>
          <label class="mt-2 flex items-center gap-2 text-sm text-indigo-900">
            <input type="hidden" name="filter[exclude_subspecies]" value="false" />
            <input
              type="checkbox"
              name="filter[exclude_subspecies]"
              value="true"
              checked={@filter.exclude_subspecies}
              class="h-4 w-4 rounded border-indigo-300 text-indigo-600 focus:ring-indigo-500"
            /> Exclude subspecies
          </label>
        </div>

        <%!-- Date --%>
        <div>
          <label
            for={"#{@id}-date"}
            class="block text-sm font-medium font-header leading-6 text-indigo-900"
          >
            Date
          </label>
          <div>
            <input
              type="date"
              id={"#{@id}-date"}
              name="filter[date]"
              value={@filter.date && Date.to_iso8601(@filter.date)}
              class="block w-full rounded-lg border border-zinc-300 bg-white px-2 py-1 text-sm leading-6 text-zinc-900 focus:border-zinc-400 focus:ring-0"
            />
          </div>
        </div>

        <%!-- Location --%>
        <div>
          <span class="block text-sm font-medium font-header leading-6 text-indigo-900">Location</span>
          <div>
            <LocationAutocomplete.location_autocomplete
              id={"#{@id}-location"}
              current_value={@filter.location && Geo.Location.long_name(:private, @filter.location)}
              hidden_name="filter[location_id]"
              hidden_value={(@filter.location && @filter.location.id) || ""}
              placeholder=""
              on_select_event="filter_location"
              scope={@scope}
              compact
            />
          </div>
          <label class="mt-2 flex items-center gap-2 text-sm text-indigo-900">
            <input type="hidden" name="filter[include_subregions]" value="false" />
            <input
              type="checkbox"
              name="filter[include_subregions]"
              value="true"
              checked={@filter.include_subregions}
              class="h-4 w-4 rounded border-indigo-300 text-indigo-600 focus:ring-indigo-500"
            /> Include subregions
          </label>
        </div>

        <%!-- Card-level toggles (under the three text fields) --%>
        <div class="sm:col-span-2 lg:col-start-1 lg:col-span-3 lg:row-start-2">
          <label class="flex items-center gap-2 text-sm text-indigo-900">
            <span class="font-semibold">Cards:</span>
            <input type="hidden" name="filter[unresolved]" value="false" />
            <input
              type="checkbox"
              id={"#{@id}-unresolved"}
              name="filter[unresolved]"
              value="true"
              checked={@filter.unresolved}
              class="h-4 w-4 rounded border-indigo-300 text-indigo-600 focus:ring-indigo-500"
            /> Unresolved only
          </label>
        </div>

        <%!-- Voice + hidden --%>
        <div class="flex flex-col gap-3 lg:row-start-1 lg:col-start-4">
          <fieldset>
            <legend class="block text-sm font-medium font-header leading-6 text-indigo-900">
              Observations
            </legend>
            <ul class="mt-1 space-y-1">
              <li :for={{value, label} <- voice_options()}>
                <label class="flex items-center gap-2 text-sm text-indigo-900">
                  <input
                    type="radio"
                    name="filter[voice]"
                    value={value}
                    checked={to_string(@filter.voice) == value}
                    class="h-4 w-4 border-indigo-300 text-indigo-600 focus:ring-indigo-500"
                  />
                  {label}
                </label>
              </li>
            </ul>
          </fieldset>

          <label class="flex items-center gap-2 border-t border-indigo-200 pt-3 text-sm text-indigo-900">
            <input type="hidden" name="filter[hidden]" value="false" />
            <input
              type="checkbox"
              name="filter[hidden]"
              value="true"
              checked={@filter.hidden}
              class="h-4 w-4 rounded border-indigo-300 text-indigo-600 focus:ring-indigo-500"
            /> Hidden obs only
          </label>
        </div>

        <%!-- Actions --%>
        <div class="flex flex-col items-stretch gap-2 lg:row-start-1 lg:col-start-5">
          <button
            type="submit"
            class="inline-flex items-center justify-center gap-1.5 rounded-lg bg-indigo-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500"
          >
            <.icon name="hero-magnifying-glass" class="h-4 w-4" /> Search
          </button>
          <button
            :if={not Filter.blank?(@filter)}
            type="button"
            phx-click="filter_reset"
            class="inline-flex items-center justify-center gap-1.5 rounded-lg border border-indigo-300 bg-white px-4 py-2 text-sm font-semibold text-indigo-700 shadow-sm hover:bg-indigo-50"
          >
            <.icon name="hero-x-mark" class="h-4 w-4" /> Reset
          </button>
        </div>
      </div>
    </form>
    """
  end

  defp voice_options do
    [{"all", "All"}, {"seen", "Seen"}, {"heard_only", "Heard only"}]
  end
end
