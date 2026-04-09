defmodule KjogviWeb.Partials do
  @moduledoc """
  Top level partials.
  """

  use KjogviWeb, :html

  import KjogviWeb.AdminMenuComponents

  require Kjogvi.Config

  embed_templates "partials/*"

  attr :list, :list, doc: "List of observations", required: true
  attr :total, :integer, doc: "Total number of species", required: true
  attr :class, :string, doc: "Class of the top-level section", default: ""
  attr :href, :string, doc: "Link to the full list", default: nil
  slot :header, required: true
  def top_n_list(assigns)
end
