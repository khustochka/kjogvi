defmodule KjogviWeb.Components.SearchAutocomplete do
  @moduledoc """
  Reusable autocomplete/search components for locations and taxa.
  Can be used across different pages and features.
  """

  use Phoenix.Component

  alias KjogviWeb.IconComponents
  alias KjogviWeb.CoreComponents

  import IconComponents

  @doc """
  Renders an autocomplete input for taxa search.

  ## Attributes
    * field - The form field
    * label - The label text
    * target - The component that will handle search events
    * search_results - List of search results to display
    * loading - Whether a search is in progress
  """
  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, required: true
  attr :target, :any, default: nil
  attr :search_results, :list, default: []
  attr :loading, :boolean, default: false
  attr :placeholder, :string, default: "Search..."

  def taxa_autocomplete(assigns) do
    ~H"""
    <div class="relative">
      <CoreComponents.input
        type="text"
        field={@field}
        label={@label}
        placeholder={@placeholder}
        phx-target={@target}
        phx-keyup="search_taxa"
        autocomplete="off"
      />

      <%= if @loading do %>
        <div class="absolute right-3 top-10 text-gray-400">
          <.icon name="hero-arrow-path" class="w-5 h-5 animate-spin" />
        </div>
      <% end %>

      <%= if !Enum.empty?(@search_results) do %>
        <div class="absolute top-full left-0 right-0 mt-1 bg-white border border-gray-300 rounded-lg shadow-lg z-50 max-h-64 overflow-y-auto">
          <%= for result <- @search_results do %>
            <div
              class="px-4 py-2 hover:bg-gray-100 cursor-pointer border-b last:border-b-0"
              phx-target={@target}
              phx-click="select_taxon"
              phx-value-code={result.code}
              phx-value-name={result.name_en}
            >
              <div class="font-medium text-sm">{result.name_en}</div>
              <div class="text-xs text-gray-500 italic">{result.name_sci}</div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders an autocomplete input for location search.

  ## Attributes
    * field - The form field
    * label - The label text
    * target - The component that will handle search events
    * search_results - List of search results to display
    * loading - Whether a search is in progress
  """
  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, required: true
  attr :target, :any, default: nil
  attr :search_results, :list, default: []
  attr :loading, :boolean, default: false
  attr :placeholder, :string, default: "Search locations..."

  def location_autocomplete(assigns) do
    ~H"""
    <div class="relative">
      <CoreComponents.input
        type="text"
        field={@field}
        label={@label}
        placeholder={@placeholder}
        phx-target={@target}
        phx-keyup="search_locations"
        autocomplete="off"
      />

      <%= if @loading do %>
        <div class="absolute right-3 top-10 text-gray-400">
          <.icon name="hero-arrow-path" class="w-5 h-5 animate-spin" />
        </div>
      <% end %>

      <%= if !Enum.empty?(@search_results) do %>
        <div class="absolute top-full left-0 right-0 mt-1 bg-white border border-gray-300 rounded-lg shadow-lg z-50 max-h-64 overflow-y-auto">
          <%= for result <- @search_results do %>
            <div
              class="px-4 py-2 hover:bg-gray-100 cursor-pointer border-b last:border-b-0"
              phx-target={@target}
              phx-click="select_location"
              phx-value-id={result.id}
              phx-value-name={result.name}
            >
              <div class="font-medium text-sm">{result.name}</div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
