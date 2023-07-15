defmodule KjogviWeb.TaxaLive.Index do
  use KjogviWeb, :live_component

  @minimum_search_term_length 3

  import KjogviWeb.PaginationComponents

  @impl true
  def update(%{book: book, page_num: page_num}, socket) do
    {:ok,
     socket
     |> assign(:book, book)
     |> assign(:page_num, page_num)
     |> assign_search_state(nil)
     |> assign_taxa
    }
  end

  @impl true
  def handle_event("search_updated", %{"search_term" => search_term}, socket) do
    {:noreply,
      socket
      |> assign_search_state(search_term)
      |> assign_taxa
    }
  end

  attr :book, Ornitho.Schema.Book, required: true
  attr :taxa, :list, required: true
  attr :pagenum, :integer, default: 1
  attr :search_enabled, :boolean, default: false

  def render(assigns) do
    ~H"""
    <div>
      <form class="mt-5 mb-4" id="taxa-search"
          phx-change="search_updated" phx-target={@myself} phx-debounce="200">
        <.input type="search" name="search_term" label="Search taxa"
            id="search_term" value={@search_term} errors={[]} />
      </form>

      <.live_component module={KjogviWeb.TaxaLive.Table} id="taxa-table" book={@book} taxa={@taxa} />

      <.simple_pagination
        :if={!@search_enabled}
        page_num={@page_num}
        url_generator={&~p"/taxonomy/#{@book.slug}/#{@book.version}/page/#{&1}"} />
    </div>
    """
  end

  defp assign_search_state(socket, nil = _search_term) do
    socket
    |> assign(:search_term, nil)
    |> assign(:search_enabled, false)
  end

  defp assign_search_state(socket, "" = _search_term) do
    assign_search_state(socket, nil)
  end

  defp assign_search_state(socket, search_term) when is_binary(search_term) do
    normalized_term = String.trim(search_term)
    socket
    |> assign(:search_term, normalized_term)
    |> assign(:search_enabled, String.length(normalized_term) >= @minimum_search_term_length)
  end

  defp assign_taxa(socket) do
    socket
    |> assign(:taxa, get_taxa(socket.assigns))
  end

  defp get_taxa(%{book: book, search_enabled: false, page_num: page_num}) do
    Ornitho.Finder.Taxon.page(book, page_num)
    |> Ornitho.Finder.Taxon.with_parent_species()
  end

  defp get_taxa(%{book: book, search_enabled: true, search_term: search_term}) do
    Ornitho.Finder.Taxon.search(book, search_term, limit: 15)
    |> Ornitho.Finder.Taxon.with_parent_species()
  end
end
