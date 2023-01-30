defmodule Ornitho.Importer.Demo.V1 do
  @moduledoc """
  Importer for a demo book. Also used in tests.
  """

  use Ornitho.Importer.Generic,
    slug: "demo",
    version: "v1",
    name: "Demo book"
end
