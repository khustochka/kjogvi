defmodule Ornitho.Importer do
  @moduledoc """
  The module that does book import.
  """

  def process_import(importer, opts \\ []) do
    force = opts[:force]

    with {:module, _} <- Code.ensure_compiled(importer),
         {:ok, _} <- prepare_repo(importer, force: force),
         {:ok, book} <- create_book(importer) do
      create_taxa(importer, book)
      {:ok, :done}
    else
      {:error, :nofile} -> {:error, :incorrect_importer_module}
      e = {:error, :overwrite_not_allowed} -> e
    end
  end

  def prepare_repo(importer, opts \\ []) do
    force = opts[:force]

    if book_exists?(importer) do
      if force == true do
        delete_book(importer)
        {:ok, :ready}
      else
        {:error, :overwrite_not_allowed}
      end
    else
      {:ok, :ready}
    end
  end

  defp book_exists?(importer) do
    importer.book_query()
    |> Ornitho.Repo.exists?()
  end

  defp delete_book(importer) do
    importer.book_query()
    |> Ornitho.Repo.delete_all()
  end

  defp create_book(importer) do
    importer.book_map()
    |> Ornitho.Repo.insert()
  end

  defp create_taxa(importer, book) do
    # importer.create_taxa(book)
  end
end
