defmodule OrnithoWeb.Live.Taxa.Index do
  @moduledoc false

  use OrnithoWeb, :live_component

  alias OrnithoWeb.Live.Taxa.SearchState

  @taxa_per_page 25

  @impl true
  def update(%{book: book, search_term: search_term, page_num: page_num}, socket) do
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

    new_search = is_nil(socket.assigns.search_state.term)

    path =
      OrnithoWeb.LinkHelper.book_path(socket, socket.assigns.book, 1, search_params)

    # Make search path replace the previous search path in history, so that when
    # clicking Back, the user won't go back one letter. But the initial, non-search, state
    # should not be replaced.
    {:noreply, socket |> push_patch(to: path, replace: not new_search)}
  end

  attr :book, Ornitho.Schema.Book, required: true
  attr :taxa, :list, required: true
  attr :next_page, :integer, default: nil
  attr :search_enabled, :boolean, default: false
  attr :search_term, :string, default: nil

  @impl true
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

      <div id="taxa-list">
        <.page_nav
          id="taxa-pagination-top"
          socket={@socket}
          book={@book}
          prev_page={@prev_page}
          next_page={@next_page}
        />

        <OrnithoWeb.Live.Taxa.Table.render
          book={@book}
          taxa={@taxa}
          search_state={@search_state}
          link_builder={&OrnithoWeb.LinkHelper.path(@socket, &1)}
        />
      </div>

      <.page_nav
        id="taxa-pagination-bottom"
        socket={@socket}
        book={@book}
        prev_page={@prev_page}
        next_page={@next_page}
      />
    </div>
    """
  end

  attr :id, :string, required: true
  attr :socket, :any, required: true
  attr :book, Ornitho.Schema.Book, required: true
  attr :prev_page, :any, required: true
  attr :next_page, :any, required: true

  defp page_nav(assigns) do
    ~H"""
    <nav :if={@prev_page || @next_page} id={@id} class="my-4">
      <ul class="flex justify-center gap-3">
        <li :if={@prev_page}>
          <.link
            id={"#{@id}-prev"}
            patch={page_path(@socket, @book, @prev_page)}
            rel="prev"
            class={link_class()}
          >← Previous page</.link>
        </li>
        <li :if={@next_page}>
          <.link
            id={"#{@id}-next"}
            patch={page_path(@socket, @book, @next_page)}
            rel="next"
            class={link_class()}
          >Next page →</.link>
        </li>
      </ul>
    </nav>
    """
  end

  defp link_class do
    "inline-block rounded-lg bg-zinc-900 hover:bg-zinc-700 py-2 px-3 " <>
      "text-sm font-semibold leading-6 text-white active:text-white/80 no-underline"
  end

  defp assign_search_state(socket, search_term) do
    socket
    |> assign(:search_state, SearchState.assign_search_term(search_term))
  end

  # Search results are a plain top-N list, so paging only applies when the
  # search box is empty.
  defp assign_taxa(%{assigns: %{search_state: %{enabled: true, term: term}}} = socket) do
    taxa =
      Ornitho.Finder.Taxon.search(socket.assigns.book, term, limit: 15)
      |> Ornitho.Finder.Taxon.with_parent_species()

    socket
    |> assign(:taxa, taxa)
    |> assign(:prev_page, nil)
    |> assign(:next_page, nil)
  end

  defp assign_taxa(socket) do
    {taxa, meta} =
      Ornitho.Finder.Taxon.page(socket.assigns.book,
        page: socket.assigns.page_num,
        page_size: @taxa_per_page
      )
      |> Ornitho.Finder.Taxon.with_parent_species()

    socket
    |> assign(:taxa, taxa)
    |> assign(:prev_page, meta.has_previous_page? && meta.current_page - 1)
    |> assign(:next_page, meta.has_next_page? && meta.current_page + 1)
  end

  # Anchored above the pagination so a page change lands on the controls and the
  # taxa below them, not on the book header.
  defp page_path(socket, book, page) do
    OrnithoWeb.LinkHelper.book_path(socket, book, page) <> "#taxa-list"
  end
end
