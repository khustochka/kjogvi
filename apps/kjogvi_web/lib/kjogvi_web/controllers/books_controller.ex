defmodule KjogviWeb.BooksController do
  use KjogviWeb, :controller

  def index(conn, _params) do
    books = Ornitho.Finder.Book.with_taxa_count()

    conn
    |> assign(:books, books)
    |> assign(:page_title, "Books")
    |> render(:index)
  end

  def show(conn, %{"slug" => slug, "version" => version, "page" => page_str}) do
    # TODO: validate page number; redirect to default if number is 1
    page = String.to_integer(page_str)
    book = Ornitho.Finder.Book.by_signature(slug, version)
    taxa = Ornitho.Finder.Taxon.page(book, page)

    conn
    |> assign(:book, book)
    |> assign(:taxa, taxa)
    |> assign(:page_num, page)
    |> assign(:page_title, book.name)
    |> render(:show)
  end

  def show(conn, assigns) do
    show(conn, Map.put(assigns, "page", "1"))
  end
end
