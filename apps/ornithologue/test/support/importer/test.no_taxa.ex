defmodule Ornitho.Importer.Test.NoTaxa do
  use Ornitho.Importer,
    slug: "test", version: "no_taxa", name: "Test book with no taxa",
    description: "This is a test book"
end
