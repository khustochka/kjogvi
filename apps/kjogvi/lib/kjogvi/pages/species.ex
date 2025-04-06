defmodule Kjogvi.Pages.Species do
  @moduledoc """
  Species Page schema.
  """

  use Kjogvi.Schema

  alias Kjogvi.Pages.Species

  @primary_key false
  embedded_schema do
    field :name_sci, :string
    field :code, :string
    field :name_en, :string
  end

  def from_slug(slug) do
    %Species{name_sci: String.replace(slug, "_", " ", global: false)}
  end

  def from_taxon(nil) do
    nil
  end

  def from_taxon(taxon) do
    %Species{name_sci: taxon.name_sci, code: taxon.code, name_en: taxon.name_en}
  end
end
