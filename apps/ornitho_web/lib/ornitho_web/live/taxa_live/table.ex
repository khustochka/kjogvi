defmodule OrnithoWeb.TaxaLive.Table do
  use OrnithoWeb, :live_component

  import OrnithoWeb.TaxaComponents

  @impl true
  def handle_event("expand_taxon", %{"code" => code}, socket) do
    {:noreply,
     socket
     |> assign(:expanded_taxon, code)}
  end

  @impl true
  def handle_event("collapse_taxon", _params, socket) do
    {:noreply,
     socket
     |> assign(:expanded_taxon, nil)}
  end

  attr :book, Ornitho.Schema.Book, required: true
  attr :taxa, :list, required: true
  attr :skip_parent_species, :boolean, default: false
  attr :expanded_taxon, :string, default: nil

  def render(assigns) do
    ~H"""
    <div id={@id} class="overflow-y-auto px-4 sm:overflow-visible sm:px-0">
      <table class="mt-6 w-[40rem] sm:w-full">
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
                <%= taxon.sort_order %>
              </td>
              <td class="p-0 py-4 pr-6">
                <span class="font-mono"><%= taxon.code %></span>
              </td>
              <td class="p-0 py-4 pr-6">
                <div class="text-zinc-900">
                  <div>
                    <div>
                      <strong>
                        <.link navigate={OrnithoWeb.LinkHelper.path(@socket, "/#{@book.slug}/#{@book.version}/#{taxon.code}")}>
                          <.sci_name taxon={taxon} />
                        </.link>
                      </strong>
                      <.category_tag :if={taxon.category} category={taxon.category} />
                      <.extinct_tag taxon={taxon} />
                    </div>
                    <div :if={taxon.authority} class="text-zinc-500 text-xs">
                      <%= Ornitho.Schema.Taxon.formatted_authority(taxon) %>
                    </div>
                  </div>
                </div>
                <div>
                  <%= taxon.name_en %>
                  <% # Future: <.highlighted content={taxon.name_en} term={@search_term} /> %>
                </div>
              </td>
              <td :if={!@skip_parent_species} class="p-0 py-4 pr-6 text-center">
                <.link
                  :if={taxon.parent_species}
                  navigate={OrnithoWeb.LinkHelper.path(@socket, "/#{@book.slug}/#{@book.version}/#{taxon.parent_species.code}")}
                >
                  <.sci_name taxon={taxon.parent_species} />
                </.link>
              </td>
              <td class="p-0 py-4 pr-6">
                <div><%= taxon.order %></div>
                <div><%= taxon.family %></div>
              </td>
              <td class="p-0 py-4 pr-6">
                <span
                  :if={taxon.code != @expanded_taxon}
                  phx-click="expand_taxon"
                  phx-target={@myself}
                  phx-value-code={taxon.code}
                  class="hover:cursor-pointer"
                >
                  <.icon name="hero-chevron-down-solid" class="w-6 h-6" />
                  <span class="sr-only">Expand</span>
                </span>
                <span
                  :if={taxon.code == @expanded_taxon}
                  phx-click="collapse_taxon"
                  phx-target={@myself}
                  class="hover:cursor-pointer"
                >
                  <.icon name="hero-chevron-up-solid" class="w-6 h-6" />
                  <span class="sr-only">Collapse</span>
                </span>
              </td>
            </tr>
            <tr :if={taxon.code == @expanded_taxon}>
              <td></td>
              <td class="p-0 py-4 pr-6" colspan={if @skip_parent_species, do: 4, else: 5}>
                <.list>
                  <:item :for={{key, value} <- taxon.extras || %{}} title={key}>
                    <%= value %>
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
end
