defmodule Kjogvi.Pages do
  @moduledoc """
  Operations with pages that represent species.

  TODO: find better name/structure.
  """

  import Ecto.Query

  alias Ornitho.Schema.Taxon

  # alias Kjogvi.Birding.Observation
  alias Kjogvi.Pages.Species
  alias Kjogvi.Pages.SpeciesTaxaMapping
  alias Kjogvi.Repo

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
    |> Ornithologue.get_taxa_and_species()
    |> Enum.uniq()
    |> Enum.map(fn {_key, taxon} -> promote_taxon(taxon) end)
  end

  def promote_taxon(taxon) do
    species = Taxon.species(taxon)

    taxon_species_page = Species.from_taxon(taxon)
    species_species_page = Species.from_taxon(species)

    cond do
      is_nil(species) ->
        nil

      not is_nil(taxon_species_page) ->
        taxon_species_page

      not is_nil(species_species_page) ->
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
        # not all may be relevant
        extras: taxon.extras,
        sort_order: taxon.sort_order
      })
      |> Repo.insert()

    species_page
    |> Ecto.build_assoc(:species_taxa_mappings, taxon_key: Taxon.key(taxon))
    |> Repo.insert()

    species_page
  end
end
