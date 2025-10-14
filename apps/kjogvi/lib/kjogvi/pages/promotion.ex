defmodule Kjogvi.Pages.Promotion do
  @moduledoc """
  Promotiong means creating previouisly non-exisitng pages for species.

  When a new observation is added, we may need to create a new species page,
  otherwise it will not be included in the lifelist.
  """

  import Ecto.Query

  alias Ornitho.Schema.Taxon

  # alias Kjogvi.Birding.Observation
  alias Kjogvi.Pages.Species
  alias Kjogvi.Pages.SpeciesTaxaMapping
  alias Kjogvi.Repo

  # Extras fields to copy from taxon.
  @extras_fields ["species_group", "extinct", "extinct_year"]

  # def promote_observations_by_list(observations) do
  #   taxa_keys = Enum.map(observations, & Map.take(&1, [:taxon_key]))

  #   all_mappings = from stm in SpeciesTaxaMapping, select: stm.taxon_key

  #   query = from tkey in values(taxa_keys, %{taxon_key: :string}),
  #     where: tkey.taxon_key not in subquery(all_mappings),
  #     select: tkey.taxon_key

  #   unmapped_keys =
  #     query
  #     |> Repo.all()

  # end

  def promote_observations_by_query(obs_query) do
    query =
      from o in obs_query,
        left_join: stm in SpeciesTaxaMapping,
        on: o.taxon_key == stm.taxon_key,
        where: is_nil(stm.taxon_key),
        select: o.taxon_key,
        distinct: true

    unmapped_keys = Repo.all(query)

    unmapped_keys
    |> Ornithologue.get_taxa_and_species(format: :full)
    |> Enum.uniq()
    |> Enum.map(fn {_key, taxon} -> promote_taxon(taxon) end)
  end

  def promote_taxon(taxon) do
    species = Taxon.species(taxon)

    cond do
      is_nil(species) ->
        nil

      not is_nil(taxon_species_page = Species.from_taxon(taxon)) ->
        taxon_species_page

      not is_nil(species_species_page = Species.from_taxon(species)) ->
        attach_taxon_to_species_page(species_species_page, taxon)

      :otherwise ->
        create_page_from_species(species)
        |> attach_taxon_to_species_page(taxon)
    end
  end

  defp attach_taxon_to_species_page(species_page, taxon) do
    if taxon.category != "species" do
      species_page
      |> Ecto.build_assoc(:species_taxa_mappings, taxon_key: Taxon.key(taxon))
      |> Repo.insert()
    end

    species_page
  end

  defp create_page_from_species(%{category: "species"} = taxon) do
    {:ok, species_page} =
      Species.changeset(%Species{}, %{
        name_sci: taxon.name_sci,
        common_name: taxon.name_en,
        name_en: taxon.name_en,
        order: taxon.order,
        family: taxon.family,
        extras: Map.take(taxon.extras, @extras_fields),
        sort_order: taxon.sort_order
      })
      |> Repo.insert()

    species_page
    |> Ecto.build_assoc(:species_taxa_mappings, taxon_key: Taxon.key(taxon))
    |> Repo.insert()

    species_page
  end
end
