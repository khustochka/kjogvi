defmodule Ornitho.Importer do
  @moduledoc """
  The module that does book import.
  """

  def process_import(importer, force: force) do
    with {:module, _} <- Code.ensure_compiled(importer),
         {:ok, _} <- prepare_repo(importer, force: force) do
      {:ok, :done}
    else
      {:error, :nofile} -> {:error, :incorrect_importer_module}
      e = {:error, :overwrite_not_allowed} -> e
    end
  end

  def prepare_repo(importer, force: force) do
    if book_exists?(importer) do
      if force do
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
    importer.taxa_query()
    |> Ornitho.Repo.delete_all()

    importer.book_query()
    |> Ornitho.Repo.delete_all()
  end
end
