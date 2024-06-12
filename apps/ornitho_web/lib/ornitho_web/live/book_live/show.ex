defmodule OrnithoWeb.Live.Book.Show do
  @moduledoc false

  use OrnithoWeb, :live_view

  import OrnithoWeb.BreadcrumbsComponents
  import OrnithoWeb.TimeComponents

  @impl true
  def mount(%{"slug" => slug, "version" => version}, _session, socket) do
    book =
      Ornitho.Finder.Book.by_signature!(slug, version)
      |> Ornitho.Finder.Book.load_taxa_count()

    {:ok,
     socket
     |> assign(:book, book)
     |> assign(:page_title, book.name)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    # TODO: validate page number; redirect to default if number is 1
    page =
      Map.get(params, "page", "1")
      |> String.to_integer()

    {:noreply,
     socket
     |> assign(:page_num, page)
     |> assign(:search_term, params["search_term"])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.breadcrumbs>
      <:crumb><b><.link href={OrnithoWeb.LinkHelper.root_path(@socket)}>Taxonomy</.link></b></:crumb>
      <:crumb><%= @book.name %></:crumb>
    </.breadcrumbs>

    <.header>
      <%= @book.name %>
      <:subtitle><%= @book.description %></:subtitle>
    </.header>
    <div class="mt-8">
      <.list>
        <:item title="Imported at"><.datetime time={@book.imported_at} /></:item>
        <:item title="Taxa"><%= @book.taxa_count %></:item>
        <:item :for={{key, value} <- @book.extras || %{}} title={key}>
          <%= value %>
        </:item>
      </.list>
    </div>
    <.live_component
      module={OrnithoWeb.Live.Taxa.Index}
      id="taxa-index"
      book={@book}
      page_num={@page_num}
      search_term={@search_term}
    />
    """
  end
end
