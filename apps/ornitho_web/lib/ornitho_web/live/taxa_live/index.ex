defmodule OrnithoWeb.Live.Taxa.Index do
  @moduledoc false

  use OrnithoWeb, :live_component

  import Scrivener.PhoenixView

  alias OrnithoWeb.Live.Taxa.SearchState

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
    search_params =
      if search_term == "" do
        []
      else
        [search_term: search_term]
      end

    path =
      OrnithoWeb.LinkHelper.book_path(socket, socket.assigns.book, 1, search_params)

    {:noreply, socket |> push_patch(to: path)}
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
        phx-submit="search_updated"
        phx-target={@myself}
        phx-debounce="200"
      >
        <.input
          type="search"
          name="search_term"
          label="Search taxa"
          id="search_term"
          value={@search_state.term}
          errors={[]}
        />
      </form>

      <OrnithoWeb.Live.Taxa.Table.render
        book={@book}
        taxa={@taxa}
        search_state={@search_state}
        link_builder={&OrnithoWeb.LinkHelper.path(@socket, &1)}
      />

      <%= if !@search_state.enabled do %>
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

  defp assign_search_state(socket, search_term) do
    socket
    |> assign(:search_state, SearchState.assign_search_term(search_term))
  end

  defp assign_taxa(socket) do
    socket
    |> assign(:taxa, get_taxa(socket.assigns))
  end

  defp get_taxa(%{book: book, search_state: %{enabled: false}, page_num: page_num}) do
    Ornitho.Finder.Taxon.paginate(book, page: page_num, page_size: @taxa_per_page)
    |> Ornitho.Finder.Taxon.with_parent_species()
  end

  defp get_taxa(%{book: book, search_state: %{enabled: true, term: search_term}}) do
    Ornitho.Finder.Taxon.search(book, search_term, limit: 15)
    |> Ornitho.Finder.Taxon.with_parent_species()
  end

  defp pagination_opts do
    @pagination_opts
  end
end
