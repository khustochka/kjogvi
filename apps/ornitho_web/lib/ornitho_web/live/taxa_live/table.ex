defmodule OrnithoWeb.Live.Taxa.Table do
  @moduledoc false

  use Phoenix.Component

  import OrnithoWeb.CoreComponents
  import OrnithoWeb.TaxaComponents

  alias OrnithoWeb.Live.Taxa.SearchState
  alias Phoenix.LiveView.JS

  attr :book, Ornitho.Schema.Book, required: true
  attr :taxa, :list, required: true
  attr :link_builder, :any, required: true
  attr :skip_parent_species, :boolean, default: false
  attr :search_state, :any, default: struct(SearchState)

  def render(assigns) do
    ~H"""
    <div class="overflow-y-auto px-4 sm:overflow-visible sm:px-0">
      <table class="mt-6 w-160 sm:w-full">
        <thead class="text-left text-[0.8125rem] leading-6 text-zinc-500">
          <tr>
            <th class="p-0 pb-4 pr-6 font-normal">no</th>
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
            <tr>
              <td class="p-0 py-4 pr-6">
                {taxon.sort_order}
              </td>
              <td class="p-0 py-4 pr-6">
                <div class="font-mono">
                  <.highlighted content={taxon.code} search_state={@search_state} />
                </div>
                <div :if={taxon.taxon_concept_id} class="font-mono">
                  <span class="text-xs text-slate-400">
                    {taxon.taxon_concept_id}
                  </span>
                </div>
              </td>
              <td class="p-0 py-4 pr-6">
                <div class="text-zinc-900">
                  <div>
                    <div>
                      <strong>
                        <.link
                          navigate={@link_builder.("/#{@book.slug}/#{@book.version}/#{taxon.code}")}
                          phx-no-format
                        ><.sci_name taxon={taxon} search_state={@search_state} /></.link>
                      </strong>
                      <.category_tag :if={taxon.category} category={taxon.category} />
                      <.extinct_tag taxon={taxon} />
                    </div>
                  </div>
                </div>
                <div>
                  <.highlighted content={taxon.name_en} search_state={@search_state} />
                </div>
              </td>
              <td :if={!@skip_parent_species} class="p-0 py-4 pr-6 text-center">
                <.link
                  :if={taxon.parent_species}
                  navigate={
                    @link_builder.("/#{@book.slug}/#{@book.version}/#{taxon.parent_species.code}")
                  }
                >
                  <.sci_name taxon={taxon.parent_species} />
                </.link>
              </td>
              <td class="p-0 py-4 pr-6">
                <div>{taxon.order}</div>
                <div>{taxon.family}</div>
              </td>
              <td class="p-0 py-4 pr-6">
                <span
                  phx-click={toggle_taxon_extra_data(taxon.code)}
                  class="hover:cursor-pointer"
                  id={"taxon-extra-data-trigger-#{taxon.code}"}
                >
                  <.icon name="hero-chevron-down-solid" class="w-6 h-6 toggle-taxon-data-icon-open" />
                  <.icon
                    name="hero-chevron-up-solid"
                    class="w-6 h-6 toggle-taxon-data-icon-close hidden"
                  />
                  <span class="sr-only">Expand/Collapse</span>
                </span>
              </td>
            </tr>
            <tr
              class={["hidden taxon-extra-data", "taxon-extra-data-#{taxon.code}"]}
              id={"taxon-extra-data-#{taxon.code}"}
            >
              <td></td>
              <td class="p-0 py-4 pr-6" colspan={if @skip_parent_species, do: 4, else: 5}>
                <.list>
                  <:item :if={taxon.authority} title="authority">
                    {Ornitho.Schema.Taxon.formatted_authority(taxon)}
                  </:item>
                  <:item :for={{key, value} <- taxon.extras || %{}} title={key}>
                    {value}
                  </:item>
                </.list>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  def collapse_all_extra_data do
    JS.hide(to: ".taxon-extra-data")
    |> JS.show(to: ".toggle-taxon-data-icon-open")
    |> JS.hide(to: ".toggle-taxon-data-icon-close")
  end

  def toggle_taxon_extra_data(code) do
    collapse_all_extra_data()
    |> JS.toggle(to: ".taxon-extra-data-#{code}")
    |> JS.toggle(to: {:inner, ".toggle-taxon-data-icon-open"})
    |> JS.toggle(to: {:inner, ".toggle-taxon-data-icon-close"})
  end
end
