defmodule KjogviWeb.TaxaLive.Show do
  use KjogviWeb, :live_view

  import KjogviWeb.BreadcrumbsComponents
  import KjogviWeb.TaxaComponents

  @impl true
  def mount(%{"slug" => slug, "version" => version, "code" => _code}, _session, socket) do
    book = Ornitho.Finder.Book.by_signature(slug, version)

    {:ok,
     socket
     |> assign(:book, book)}
  end

  @impl true
  def handle_params(%{"slug" => _slug, "version" => _version, "code" => code}, _, socket) do
    taxon =
      Ornitho.Finder.Taxon.by_code(socket.assigns.book, code)
      |> Ornitho.Finder.Taxon.with_parent_species()
      |> Ornitho.Finder.Taxon.with_child_taxa()

    {:noreply,
     socket
     |> assign(:taxon, taxon)
     |> assign(:page_title, "#{taxon.name_sci} · #{socket.assigns.book.name}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.breadcrumbs>
      <:crumb><b><.link href={~p"/taxonomy"}>Taxonomy</.link></b></:crumb>
      <:crumb>
        <b>
          <.link navigate={~p"/taxonomy/#{@book.slug}/#{@book.version}"}><%= @book.name %></.link>
        </b>
      </:crumb>
      <:crumb><.sci_name taxon={@taxon} /></:crumb>
    </.breadcrumbs>

    <.header>
      <.sci_name taxon={@taxon} />
      <.category_tag category={@taxon.category} />
      <:subtitle><%= @taxon.name_en %></:subtitle>
    </.header>
    <div class="mt-8">
      <.list>
        <:item title="Order #"><%= @taxon.sort_order %></:item>
        <:item :if={@taxon.authority} title="Authority">
          <%= Ornitho.Schema.Taxon.formatted_authority(@taxon) %>
        </:item>
        <:item :if={@taxon.protonym} title="Protonym"><%= @taxon.protonym %></:item>
        <:item :if={@taxon.order || @taxon.family} title="Taxonomy">
          <%= @taxon.order %> / <%= @taxon.family %>
        </:item>
        <:item title="Code"><span class="font-mono"><%= @taxon.code %></span></:item>
        <:item :if={@taxon.parent_species} title="Parent species">
          <.link patch={~p"/taxonomy/#{@book.slug}/#{@book.version}/#{@taxon.parent_species.code}"}>
            <.sci_name taxon={@taxon.parent_species} />
          </.link>
        </:item>
        <:item :for={{key, value} <- @taxon.extras || %{}} title={key}>
          <%= value %>
        </:item>
      </.list>
    </div>
    <div :if={@taxon.child_taxa != []} class="mt-6">
      <h2>Child taxa</h2>
      <.live_component
        module={KjogviWeb.TaxaLive.Table}
        id="child-taxa-table"
        book={@book}
        taxa={@taxon.child_taxa}
        skip_parent_species={true}
      />
    </div>
    """
  end
end
