defmodule Ornitho.Crosswalk do
  @moduledoc """
  Matches taxa from one taxonomy book to their counterparts in another.

  A taxon is matched by its Avibase `taxon_concept_id`, then via its parent
  species' concept. Concepts change whenever a taxon is drawn wider or
  narrower, so the same `name_sci` with a different concept is deliberately not
  a match: after a split it would name only part of the original taxon.

  Taxa that don't resolve to a species (spuhs, slashes, hybrids) and have no
  concept match are not matched: target books often have no such categories,
  so their absence is expected rather than a problem.
  """

  alias Ornitho.Query
  alias Ornitho.Schema.Book
  alias Ornitho.Schema.Taxon

  @typedoc """
  * `{:taxon, target}` — the taxon itself (any taxon of the target book matches itself).
  * `{:species, target}` — the counterpart of the taxon's parent species.
  * `:no_species` — the taxon has no species to fall back to.
  * `:unmatched` — neither the taxon nor its species has a counterpart.
  """
  @type match() :: {:taxon, Taxon.t()} | {:species, Taxon.t()} | :no_species | :unmatched

  @doc """
  Matches `taxa` (with `book` and `parent_species` loaded, as returned by
  `Ornithologue.get_taxa_and_species/2`) in `book`, keyed by source taxon key.

  Target taxa come with `book` and `parent_species` set.
  """
  @spec match([Taxon.t()], Book.t()) :: %{String.t() => match()}
  def match(taxa, %Book{} = book) do
    index = target_index(taxa, book)

    Map.new(taxa, &{Taxon.key(&1), match_one(&1, book, index)})
  end

  defp match_one(%Taxon{book_id: book_id} = taxon, %Book{id: book_id}, _index),
    do: {:taxon, taxon}

  defp match_one(taxon, _book, index) do
    case find(taxon, index) do
      nil -> match_species(Taxon.species(taxon), index)
      target -> {:taxon, target}
    end
  end

  defp match_species(nil, _index), do: :no_species

  defp match_species(species, index) do
    case find(species, index) do
      nil -> :unmatched
      target -> {:species, target}
    end
  end

  defp find(%Taxon{taxon_concept_id: nil}, _index), do: nil
  defp find(%Taxon{taxon_concept_id: concept_id}, index), do: index[concept_id]

  # Target taxa sharing a concept with the source taxa or their species, by concept.
  defp target_index(taxa, book) do
    lookups =
      taxa
      |> Enum.reject(&(&1.book_id == book.id))
      |> Enum.flat_map(&[&1, Taxon.species(&1)])
      |> Enum.reject(&is_nil/1)

    concept_ids =
      lookups |> Enum.map(& &1.taxon_concept_id) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    Query.Taxon.by_book(book)
    |> Query.Taxon.by_concept_ids(concept_ids)
    |> Ornitho.Repo.all()
    |> Ornitho.Repo.preload(:parent_species)
    |> Map.new(&{&1.taxon_concept_id, put_book(&1, book)})
  end

  defp put_book(%Taxon{parent_species: nil} = taxon, book), do: %{taxon | book: book}

  defp put_book(%Taxon{parent_species: species} = taxon, book),
    do: %{taxon | book: book, parent_species: %{species | book: book}}
end
