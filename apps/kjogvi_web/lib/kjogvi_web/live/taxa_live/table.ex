defmodule KjogviWeb.TaxaLive.Table do
  use KjogviWeb, :live_component

  import KjogviWeb.TaxaComponents

  attr :skip_parent_species, :boolean, default: false
  attr :book, Ornitho.Schema.Book, required: true
  attr :taxa, :list, required: true

  def render(assigns) do
    ~H"""
    <div>
      <.simpler_table id="taxa" rows={@taxa}>
        <:col :let={taxon} label="no"><%= taxon.sort_order %></:col>
        <:col :let={taxon} label="code">
            <span class="font-mono"><%= taxon.code %></span>
        </:col>
        <:col :let={taxon} label="name">
            <div class="text-zinc-900">
            <strong>
            <.link navigate={~p"/taxonomy/#{@book.slug}/#{@book.version}/#{taxon}"}>
            <i><%= taxon.name_sci %></i></.link></strong>
            <span :if={taxon.authority} class="ml-2 text-zinc-500 text-xs">
            <%= Ornitho.Schema.Taxon.formatted_authority(taxon)%>
            </span>
            </div>
            <div><%= taxon.name_en %></div>
        </:col>
        <:col :let={taxon} label="category & parent species">
            <div class="text-center" :if={taxon.category}>
                <.category_tag category={taxon.category} />
            </div>
            <div class="text-center" :if={!@skip_parent_species && taxon.parent_species}>
            <.link navigate={~p"/taxonomy/#{@book.slug}/#{@book.version}/#{taxon.parent_species.code}"}>
            <i><%= taxon.parent_species.name_sci %></i>
            </.link>
            </div>
        </:col>
        <:col :let={taxon} label="taxonomy">
            <div><%= taxon.order %></div>
            <div><%= taxon.family %></div>
        </:col>
      </.simpler_table>
    </div>
    """
  end
end
