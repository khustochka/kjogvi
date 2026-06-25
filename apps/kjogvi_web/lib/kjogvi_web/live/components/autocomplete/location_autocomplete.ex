defmodule KjogviWeb.Live.Components.LocationAutocomplete do
  @moduledoc """
  Location-specific autocomplete field.

  Wraps `Autocomplete.Field` with `Kjogvi.Geo.search_locations/3` and renders
  results using each location's `:long_name`.

  Selection emits the standard
  `{:autocomplete_select, on_select_event, %{"result" => result, ...}}`
  message to the parent.
  """

  use KjogviWeb, :html

  alias Kjogvi.Geo
  alias Kjogvi.Geo.Location
  alias KjogviWeb.Live.Components.Autocomplete
  alias KjogviWeb.Live.Components.Autocomplete.Highlight

  attr :id, :string, required: true
  attr :hidden_name, :string, required: true
  attr :hidden_value, :any, default: ""
  attr :current_value, :string, default: ""

  attr :label, :string, default: nil
  attr :placeholder, :string, default: nil
  attr :on_select_event, :string, required: true
  attr :on_select_params, :map, default: %{}
  attr :compact, :boolean, default: false
  attr :errors, :list, default: []

  # Scope whose visible locations the search is restricted to.
  attr :scope, Kjogvi.Scope, required: true

  # Purpose-driven refinement of the suggestions (e.g. hide `special` locations).
  attr :filter, Location.Filter, default: %Location.Filter{}

  def location_autocomplete(assigns) do
    assigns =
      assign(assigns, :search_fn, {Geo, :suggest_locations, [assigns.scope, assigns.filter]})

    ~H"""
    <.live_component
      module={Autocomplete}
      id={@id}
      hidden_name={@hidden_name}
      hidden_value={@hidden_value}
      input_value={@current_value}
      label={@label}
      placeholder={@placeholder}
      search_fn={@search_fn}
      on_select_event={@on_select_event}
      on_select_params={@on_select_params}
      compact={@compact}
      errors={@errors}
    >
      <:result :let={%{result: result, term: term}}>
        <Highlight.highlighted_text text={Location.long_name(:private, result)} term={term} />
      </:result>
    </.live_component>
    """
  end
end
