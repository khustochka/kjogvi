defmodule OrnithoWeb.BooksController do
  use OrnithoWeb, :controller

  def index(conn, _params) do
    books = Ornitho.Finder.Book.with_taxa_count()

    conn
    |> assign(:books, books)
    |> assign(:page_title, "Books")
    |> render(:index)
  end
end
