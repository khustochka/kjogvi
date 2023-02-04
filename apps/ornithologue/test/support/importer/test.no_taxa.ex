defmodule Ornitho.Importer.Test.NoTaxa do
  @moduledoc "Test importer with no taxa. Do not add taxa!"

  use Ornitho.Importer,
    slug: "test", version: "no_taxa", name: "Test book with no taxa",
    description: "This is a test book"

  def create_taxa(_book) do
    {:ok, []}
  end
end
