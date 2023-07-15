defmodule KjogviWeb.TaxaLive.Show do
  use KjogviWeb, :live_view

  import KjogviWeb.TaxaComponents

  @impl true
  def mount(%{"slug" => slug, "version" => version, "code" => _code}, _session, socket) do
    book = Ornitho.Finder.Book.by_signature(slug, version)

    {:ok,
     socket
     |> assign(:book, book)
    }
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
     |> assign(:page_title, "#{taxon.name_sci} · #{socket.assigns.book.name}")
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="breadcrumbs mb-6 text-xs">
      <b><.link href={~p"/taxonomy"}>Taxonomy</.link></b>
      <span class="mx-1 text-sm text-zinc-400">/</span>
      <b><.link navigate={~p"/taxonomy/#{@book.slug}/#{@book.version}"}><%= @book.name %></.link></b>
      <span class="mx-1 text-sm text-zinc-400">/</span>
      <i><%= @taxon.name_sci %></i>
    </div>
    <.header>
      <i><%= @taxon.name_sci %></i>
      <.category_tag category={@taxon.category} />
      <:subtitle><%= @taxon.name_en %></:subtitle>
    </.header>
    <.list>
    <:item title="Order #"><%= @taxon.sort_order %></:item>
    <:item title="Authority" :if={@taxon.authority}><%= Ornitho.Schema.Taxon.formatted_authority(@taxon) %></:item>
    <:item title="Protonym" :if={@taxon.protonym}><%= @taxon.protonym %></:item>
    <:item title="Taxonomy" :if={@taxon.order || @taxon.family}><%= @taxon.order %> / <%= @taxon.family %></:item>
    <:item title="Code"><span class="font-mono"><%= @taxon.code %></span></:item>
    <:item title="Parent species" :if={@taxon.parent_species}>
    <.link patch={~p"/taxonomy/#{@book.slug}/#{@book.version}/#{@taxon.parent_species.code}"}>
    <i><%= @taxon.parent_species.name_sci %></i>
    </.link>
    </:item>
    <:item :for={{key, value} <- (@taxon.extras || %{})} title={key}>
    <%= value %>
    </:item>
    </.list>
    <div :if={@taxon.child_taxa != []} class="mt-6">
    <h2>Child taxa</h2>
    <.live_component module={KjogviWeb.TaxaLive.Table} id="child-taxa-table" book={@book} taxa={@taxon.child_taxa} skip_parent_species={true} />
    </div>
    """
  end
end
