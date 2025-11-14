defmodule Kjogvi.Pages.SpeciesTaxaMapping do
  @moduledoc """
  Mapping between taxa and species.
  """

  use Kjogvi.Schema

  alias Kjogvi.Pages.Species

  schema "species_taxa_mappings" do
    field(:taxon_key, :string)

    belongs_to :species_page, Species

    timestamps()
  end
end
