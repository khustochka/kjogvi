defmodule OrnithoWeb.Live.Taxa.Index do
  @moduledoc false

  use OrnithoWeb, :live_component

  import Scrivener.PhoenixView

  @minimum_search_term_length 3
  @taxa_per_page 25
  @pagination_opts [window: 2, template: OrnithoWeb.Scrivener.Phoenix.Template]

  @impl true
  def update(%{book: book, page_num: page_num, search_term: search_term}, socket) do
    {:ok,
     socket
     |> assign(:book, book)
     |> assign(:page_num, page_num)
     |> assign_search_state(search_term)
     |> assign_taxa}
  end

  @impl true
  def handle_event("search_updated", %{"search_term" => search_term}, socket) do
    {:noreply,
     socket
     |> assign_search_state(search_term)
     |> assign_taxa}
  end

  attr :book, Ornitho.Schema.Book, required: true
  attr :taxa, :list, required: true
  attr :page_num, :integer, default: 1
  attr :search_enabled, :boolean, default: false
  attr :search_term, :string, default: nil

  def render(assigns) do
    ~H"""
    <div>
      <form
        id="taxa-search"
        role="search"
        class="mt-5 mb-4"
        phx-change="search_updated"
        phx-target={@myself}
        phx-debounce="200"
      >
        <.input
          type="search"
          name="search_term"
          label="Search taxa"
          id="search_term"
          value={@search_term}
          errors={[]}
        />
      </form>

      <.live_component
        module={OrnithoWeb.Live.Taxa.Table}
        id="taxa-table"
        book={@book}
        taxa={@taxa}
        search_term={@search_term}
      />

      <%= if !@search_enabled do %>
        {paginate(
          @socket,
          @taxa,
          &OrnithoWeb.LinkHelper.book_path/4,
          [@book],
          Keyword.merge([live: true], pagination_opts())
        )}
      <% end %>
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
    Ornitho.Finder.Taxon.paginate(book, page: page_num, page_size: @taxa_per_page)
    |> Ornitho.Finder.Taxon.with_parent_species()
  end

  defp get_taxa(%{book: book, search_enabled: true, search_term: search_term}) do
    Ornitho.Finder.Taxon.search(book, search_term, limit: 15)
    |> Ornitho.Finder.Taxon.with_parent_species()
  end

  defp pagination_opts do
    @pagination_opts
  end
end
