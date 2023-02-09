defmodule KjogviWeb.BooksController do
  use KjogviWeb, :controller

  def index(conn, _params) do
    conn
    |> assign(:books, Ornitho.Find.Book.all())
    |> render(:index)
  end

  def show(conn, %{"slug" => slug, "version" => version}) do
    conn
    |> assign(:book, Ornitho.Find.Book.by_signature(slug, version))
    |> render(:show)
  end
end
