defmodule KjogviWeb.Live.Components.TaxonAutocomplete do
  @moduledoc """
  Taxon-specific autocomplete field.

  Wraps `Autocomplete.Field` with `Kjogvi.Search.Taxon.search_taxa/2` —
  scoped to the supplied user's default book — and renders each result
  with its English name plus the italicised scientific name.

  Selection emits the standard
  `{:autocomplete_select, on_select_event, %{"result" => result, ...}}`
  message to the parent.
  """

  use KjogviWeb, :html

  alias Kjogvi.Search
  alias KjogviWeb.Live.Components.Autocomplete
  alias KjogviWeb.Live.Components.Autocomplete.Highlight

  attr :id, :string, required: true
  attr :hidden_name, :string, required: true
  attr :hidden_value, :any, default: ""
  attr :current_value, :string, default: ""
  attr :user, :map, required: true

  attr :label, :string, default: nil
  attr :placeholder, :string, default: "Search and select taxon..."
  attr :on_select_event, :string, required: true
  attr :on_select_params, :map, default: %{}
  attr :compact, :boolean, default: false
  attr :errors, :list, default: []

  def taxon_autocomplete(assigns) do
    ~H"""
    <.live_component
      module={Autocomplete}
      id={@id}
      hidden_name={@hidden_name}
      hidden_value={@hidden_value}
      input_value={@current_value}
      label={@label}
      placeholder={@placeholder}
      search_fn={fn query -> Search.Taxon.search_taxa(query, @user) end}
      on_select_event={@on_select_event}
      on_select_params={@on_select_params}
      compact={@compact}
      errors={@errors}
    >
      <:result :let={%{result: result, term: term}}>
        <Highlight.highlighted_text text={result.name_en} term={term} />
        <em class="text-zinc-600">
          <Highlight.highlighted_text text={result.name_sci} term={term} />
        </em>
      </:result>
    </.live_component>
    """
  end
end
