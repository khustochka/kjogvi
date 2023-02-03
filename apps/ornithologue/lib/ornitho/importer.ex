defmodule Ornitho.Importer do
  @moduledoc """
  The module that does book import.
  """

  def process_import(importer, opts \\ []) do
    with {:module, _} <- Code.ensure_compiled(importer) do
      importer.process_import(opts)
    else
      {:error, :nofile} -> {:error, :incorrect_importer_module}
    end
  end
end
