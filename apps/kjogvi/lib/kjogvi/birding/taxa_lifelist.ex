defmodule Kjogvi.Birding.TaxaLifelist do
  @moduledoc """
  Lifelist of taxa in a single taxonomy book (`Lifelist.Filter`'s `book`),
  built straight from observations' `taxon_key`s rather than species pages.

  Observations recorded in other books are matched into the book with
  `Ornitho.Crosswalk`. Those that can't be placed are reported separately:
  `unmatched` taxa are real gaps (a species-level taxon, or a key resolving to
  no taxon at all), while `no_species` taxa (spuhs, slashes, hybrids from another
  book) simply have no counterpart.

  Called by `Kjogvi.Birding.Lifelist.generate/2` for a filter with a book.
  """

  alias Kjogvi.Birding.Lifelist.Filter
  alias Kjogvi.Birding.TaxaLifelist.Entry
  alias Kjogvi.Birding.TaxaLifelist.Query
  alias Kjogvi.Geo.Location
  alias Kjogvi.Repo
  alias Ornitho.Schema.Book
  alias Ornitho.Schema.Taxon

  @type result() :: %{list: [Entry.t()], unmatched: [Entry.t()], no_species: [Entry.t()]}

  @doc """
  First records matching `filter`, in the filter's sort order.

  Every recorded taxon is listed (subspecies, spuhs, slashes, hybrids…). With
  `species_only`, taxa are rolled up to their parent species and those without
  one are dropped.

  `unmatched` and `no_species` entries carry their source taxon (`unmatched`
  ones may have none), in source taxonomic order.
  """
  @spec generate(Kjogvi.Scope.t(), Filter.t()) :: result()
  def generate(scope, %Filter{book: %Book{} = book} = filter) do
    entries =
      Query.first_records(scope, filter)
      |> Repo.all()
      |> Enum.map(&Repo.load(Entry, &1))

    sources =
      entries
      |> Enum.map(& &1.taxon_key)
      |> Ornithologue.get_taxa_and_species(format: :full)

    matches = Ornitho.Crosswalk.match(Map.values(sources), book)

    placed =
      Enum.group_by(
        entries,
        &placement(matches[&1.taxon_key]),
        &place(&1, sources[&1.taxon_key], matches[&1.taxon_key])
      )

    %{
      list:
        Map.get(placed, :list, [])
        |> roll_up(filter.species_only)
        |> earliest_per_taxon()
        |> sort(filter.sort)
        |> Location.Query.preload_all_locations(),
      unmatched: placed |> Map.get(:unmatched, []) |> Enum.sort_by(&source_order/1),
      no_species: placed |> Map.get(:no_species, []) |> Enum.sort_by(&source_order/1)
    }
  end

  @doc """
  Number of distinct species the entries' taxa roll up to.
  """
  @spec species_count([Entry.t()]) :: non_neg_integer()
  def species_count(entries) do
    entries
    |> Enum.map(&Taxon.species(&1.taxon))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(& &1.id)
    |> length()
  end

  # A key that resolves to no taxon has no match.
  defp placement({_, %Taxon{}}), do: :list
  defp placement(:no_species), do: :no_species
  defp placement(_unmatched_or_nil), do: :unmatched

  defp place(entry, _source, {_, %Taxon{} = target}), do: %{entry | taxon: target}
  defp place(entry, source, _match), do: %{entry | taxon: source}

  defp roll_up(entries, false), do: entries

  defp roll_up(entries, true) do
    Enum.flat_map(entries, fn entry ->
      case Taxon.species(entry.taxon) do
        nil -> []
        species -> [%{entry | taxon: species}]
      end
    end)
  end

  # Several recorded taxa can land on one taxon (rolled up, or matched from
  # different books).
  defp earliest_per_taxon(entries) do
    entries
    |> Enum.group_by(& &1.taxon.id)
    |> Enum.map(fn {_id, entries} -> Enum.min_by(entries, &first_record_key/1) end)
  end

  defp sort(entries, :taxonomy), do: Enum.sort_by(entries, & &1.taxon.sort_order)
  defp sort(entries, :date), do: Enum.sort_by(entries, &newest_first_key/1, :desc)

  defp source_order(%Entry{taxon: nil, taxon_key: key}), do: {1, key, 0}
  defp source_order(%Entry{taxon: taxon}), do: {0, taxon.book_id, taxon.sort_order}

  # Matches `Observation.Query.oldest_first/1`: a missing start time sorts after any time.
  defp first_record_key(entry), do: chronological_key(entry, 1)

  # Matches the species lifelist's date sort: newest first, missing time last.
  defp newest_first_key(entry), do: chronological_key(entry, -1)

  defp chronological_key(%Entry{observ_date: date, start_time: time, id: id}, nil_rank) do
    time_key =
      case time do
        nil -> {nil_rank, 0}
        time -> {0, Time.to_seconds_after_midnight(time)}
      end

    {Date.to_gregorian_days(date), time_key, id}
  end
end
