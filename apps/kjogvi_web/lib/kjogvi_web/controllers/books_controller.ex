defmodule KjogviWeb.BooksController do
  use KjogviWeb, :controller

  def index(conn, _params) do
    books = Ornitho.Finder.Book.with_taxa_count()

    conn
    |> assign(:books, books)
    |> assign(:page_title, "Books")
    |> render(:index)
  end

  def show(conn, %{"slug" => slug, "version" => version}) do
    book = Ornitho.Finder.Book.by_signature(slug, version)
    taxa = Ornitho.Finder.Taxon.page(book, 1)

    conn
    |> assign(:book, book)
    |> assign(:taxa, taxa)
    |> assign(:page_title, book.name)
    |> render(:show)
  end
end
