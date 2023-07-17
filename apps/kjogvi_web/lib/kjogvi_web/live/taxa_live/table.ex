defmodule KjogviWeb.TaxaLive.Table do
  use KjogviWeb, :live_component

  import KjogviWeb.TaxaComponents

  @impl true
  def handle_event("expand_taxon", %{"code" => code}, socket) do
    {:noreply,
      socket
      |> assign(:expanded_taxon, code)
    }
  end

  @impl true
  def handle_event("collapse_taxon", _params, socket) do
    {:noreply,
      socket
      |> assign(:expanded_taxon, nil)
    }
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
            <th class="p-0 pb-4 pr-6 font-normal text-center" :if={!@skip_parent_species}>
              parent species
            </th>
            <th class="p-0 pb-4 pr-6 font-normal">taxonomy</th>
            <th class="p-0 pb-4 pr-6 font-normal"><span class="sr-only">expand/collapese</span></th>
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
                      <.link navigate={~p"/taxonomy/#{@book.slug}/#{@book.version}/#{taxon}"}>
                      <.sci_name taxon={taxon} /></.link>
                      </strong>
                      <.category_tag category={taxon.category} :if={taxon.category} />
                      <.extinct_tag taxon={taxon} />
                    </div>
                    <div :if={taxon.authority} class="text-zinc-500 text-xs">
                    <%= Ornitho.Schema.Taxon.formatted_authority(taxon)%>
                    </div>
                  </div>
                </div>
                <div>
                  <%= taxon.name_en %>
                  <% # Future: <.highlighted content={taxon.name_en} term={@search_term} /> %>
                </div>
              </td>
              <td class="p-0 py-4 pr-6 text-center" :if={!@skip_parent_species}>
                <.link :if={taxon.parent_species} navigate={~p"/taxonomy/#{@book.slug}/#{@book.version}/#{taxon.parent_species}"}>
                <.sci_name taxon={taxon.parent_species} /></.link>
              </td>
              <td class="p-0 py-4 pr-6">
                <div><%= taxon.order %></div>
                <div><%= taxon.family %></div>
              </td>
              <td class="p-0 py-4 pr-6">
                <div :if={taxon.code != @expanded_taxon}>
                  <.link phx-click="expand_taxon" phx-target={@myself} phx-value-code={taxon.code}>
                    <Heroicons.chevron_down class="w-6 h-6" />
                    <span class="sr-only">Expand</span>
                  </.link>
                </div>
                <div :if={taxon.code == @expanded_taxon}>
                  <.link phx-click="collapse_taxon" phx-target={@myself}>
                    <Heroicons.chevron_up class="w-6 h-6" />
                    <span class="sr-only">Collapse</span>
                  </.link>
                </div>
              </td>
            </tr>
            <tr :if={taxon.code == @expanded_taxon}>
              <td></td>
              <td class="p-0 py-4 pr-6" colspan={if @skip_parent_species, do: 4, else: 5}>
                <.list>
                  <:item :for={{key, value} <- (taxon.extras || %{})} title={key}>
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
