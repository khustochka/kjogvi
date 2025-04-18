defmodule Ornitho.Importer.Test.NoTaxa do
  @moduledoc "Test importer with no taxa. Do not add taxa!"

  use Ornitho.Importer,
    slug: "test",
    version: "no_taxa",
    name: "Test book with no taxa",
    description: "This is a test book",
    publication_date: ~D[2018-08-14]

  def create_taxa(_config, _book) do
    {:ok, []}
  end

  def validate_config do
    {:ok, nil}
  end
end
