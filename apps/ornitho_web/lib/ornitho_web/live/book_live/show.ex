defmodule OrnithoWeb.Live.Book.Show do
  @moduledoc false

  use OrnithoWeb, :live_view

  import OrnithoWeb.BreadcrumbsComponents
  import OrnithoWeb.TimeComponents

  @impl true
  def mount(%{"slug" => slug, "version" => version}, _session, socket) do
    book =
      Ornitho.Finder.Book.by_signature!(slug, version)

    {:ok,
     socket
     |> assign(:book, book)
     |> assign(:page_title, book.name)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply,
     socket
     |> assign(:search_term, params["search_term"])
     |> assign(:page_num, page_num(params["page"]))}
  end

  # The page number comes from the URL, so a junk one falls back to the first page.
  defp page_num(nil), do: 1

  defp page_num(param) do
    case Integer.parse(param) do
      {n, ""} when n > 0 -> n
      _else -> 1
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.breadcrumbs>
      <:crumb>
        <b><.breadcrumb_link href={OrnithoWeb.LinkHelper.root_path(@socket)}>Taxonomy</.breadcrumb_link></b>
      </:crumb>
      <:crumb>{@book.name}</:crumb>
    </.breadcrumbs>

    <.header>
      {@book.name}
      <:subtitle>{@book.description}</:subtitle>
    </.header>
    <div class="mt-8">
      <.list>
        <:item title="Published">{Calendar.strftime(@book.publication_date, "%-d %b %Y")}</:item>
        <:item title="Imported at"><.datetime time={@book.imported_at} /></:item>
        <:item title="Taxa">{@book.taxa_count}</:item>
        <:item :for={{key, value} <- @book.extras || %{}} title={key}>
          {value}
        </:item>
      </.list>
    </div>
    <.live_component
      module={OrnithoWeb.Live.Taxa.Index}
      id="taxa-index"
      book={@book}
      search_term={@search_term}
      page_num={@page_num}
    />
    """
  end
end
