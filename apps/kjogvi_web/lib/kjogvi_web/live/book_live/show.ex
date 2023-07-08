defmodule KjogviWeb.BookLive.Show do
  use KjogviWeb, :live_view

  import KjogviWeb.TaxaComponents
  import KjogviWeb.PaginationComponents

  @impl true
  def mount(%{"slug" => slug, "version" => version}, _session, socket) do
    book = Ornitho.Finder.Book.by_signature(slug, version)

    {:ok,
     socket
     |> assign(:book, book)
     |> assign(:page_title, book.name)}
  end

  @impl true
  def handle_params(params, _, socket) do
    # TODO: validate page number; redirect to default if number is 1
    page =
      case params["page"] do
        nil -> 1
        str -> String.to_integer(str)
      end

    taxa = Ornitho.Finder.Taxon.page(socket.assigns.book, page)

    {:noreply,
     socket
     |> assign(:taxa, taxa)
     |> assign(:page_num, page)}
  end

  # def handle_params(%{"slug" => slug, "version" => version}, _, socket) do
  #   {:noreply,
  #    socket
  #    |> assign(:page_title, page_title(socket.assigns.live_action))
  #    |> assign(:book, Bibliothek.get_book!(id))}
  # end
end
