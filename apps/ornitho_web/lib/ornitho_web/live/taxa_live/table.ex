defmodule OrnithoWeb.Live.Taxa.Table do
  @moduledoc false

  use Phoenix.Component

  alias OrnithoWeb.Live.Taxa.SearchState
  alias OrnithoWeb.Live.Taxa.TaxonRow

  attr :book, Ornitho.Schema.Book, required: false, default: nil
  attr :taxa, :list, required: true
  attr :link_builder, :any, required: true
  attr :skip_parent_species, :boolean, default: false
  attr :search_state, :any, default: struct(SearchState)
  attr :mixed_book_view, :boolean, default: false

  def render(assigns) do
    ~H"""
    <div class="overflow-y-auto px-4 sm:overflow-visible sm:px-0">
      <table class="mt-6 w-160 sm:w-full">
        <thead class="text-left text-[0.8125rem] leading-6 text-zinc-500">
          <tr>
            <th :if={!@mixed_book_view} class="p-0 pb-4 pr-6 font-normal">no</th>
            <th :if={@mixed_book_view} class="p-0 pb-4 pr-6 font-normal">book</th>
            <th class="p-0 pb-4 pr-6 font-normal">code</th>
            <th class="p-0 pb-4 pr-6 font-normal">name</th>
            <th :if={!@skip_parent_species} class="p-0 pb-4 pr-6 font-normal text-center">
              parent species
            </th>
            <th class="p-0 pb-4 pr-6 font-normal">taxonomy</th>
            <th class="p-0 pb-4 pr-6 font-normal"><span class="sr-only">expand/collapse</span></th>
          </tr>
        </thead>
        <tbody class="relative divide-y divide-zinc-100 border-t border-zinc-200 text-sm leading-6 text-zinc-700">
          <%= for taxon <- @taxa do %>
            <TaxonRow.render
              taxon={taxon}
              book={@book}
              mixed_book_view={@mixed_book_view}
              skip_parent_species={@skip_parent_species}
              search_state={@search_state}
              link_builder={@link_builder}
            />
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end
end
