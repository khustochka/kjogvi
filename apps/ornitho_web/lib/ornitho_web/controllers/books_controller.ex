defmodule OrnithoWeb.BooksController do
  use OrnithoWeb, :controller

  def index(conn, _params) do
    books = Ornitho.Finder.Book.all()

    conn
    |> assign(:books, books)
    |> assign(:page_title, "Books")
    |> assign(:importers, Ornitho.Importer.unimported())
    |> render(:index)
  end

  def import(conn, %{"importer" => importer_string} = params) do
    conn =
      if importer_string in Ornitho.Importer.legit_importers_string() do
        importer = String.to_existing_atom(importer_string)

        case importer.process_import(force: params["force"] == "true") do
          {:ok, _} -> conn
          {:error, err} -> conn |> put_flash(:error, err)
        end
      else
        conn
        |> put_flash(:error, "Not an allowed importer.")
      end

    redirect(conn, to: OrnithoWeb.LinkHelper.root_path(conn))
  end
end
