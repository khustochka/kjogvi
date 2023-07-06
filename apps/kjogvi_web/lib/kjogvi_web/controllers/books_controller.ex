defmodule KjogviWeb.BooksController do
  use KjogviWeb, :controller

  def index(conn, _params) do
    books = Ornitho.Find.Book.with_taxa_count()

    conn
    |> assign(:books, books)
    |> assign(:page_title, "Books")
    |> render(:index)
  end

  def show(conn, %{"slug" => slug, "version" => version}) do
    book = Ornitho.Find.Book.by_signature(slug, version)
    taxa = Ornitho.Find.Taxon.page(book, 1)

    conn
    |> assign(:book, book)
    |> assign(:taxa, taxa)
    |> assign(:page_title, book.name)
    |> render(:show)
  end
end
