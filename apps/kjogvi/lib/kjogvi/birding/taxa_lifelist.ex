defmodule Kjogvi.Birding.TaxaLifelist do
  @moduledoc """
  Lifelist of taxa from a single taxonomy book (`Lifelist.Filter`'s `book`),
  built straight from observations' `taxon_key`s rather than species pages.

  Observations recorded against other books are not included. Called by
  `Kjogvi.Birding.Lifelist.generate/2` for a filter with a book.
  """

  alias Kjogvi.Birding.Lifelist.Filter
  alias Kjogvi.Birding.TaxaLifelist.Entry
  alias Kjogvi.Birding.TaxaLifelist.Query
  alias Kjogvi.Geo.Location
  alias Kjogvi.Repo
  alias Ornitho.Schema.Book
  alias Ornitho.Schema.Taxon

  @doc """
  First records matching `filter`, in the filter's sort order.

  Every recorded taxon is listed (subspecies, spuhs, slashes, hybrids…). With
  `species_only`, taxa are rolled up to their parent species and those without
  one are dropped.
  """
  @spec generate(Kjogvi.Scope.t(), Filter.t()) :: [Entry.t()]
  def generate(scope, %Filter{book: %Book{}} = filter) do
    entries =
      Query.first_records(scope, filter)
      |> Repo.all()
      |> Enum.map(&Repo.load(Entry, &1))

    taxa =
      entries
      |> Enum.map(& &1.taxon_key)
      |> Ornithologue.get_taxa_and_species(format: :full)

    entries
    # A key from this book that no longer resolves to a taxon can't be placed.
    |> Enum.flat_map(fn entry ->
      case taxa[entry.taxon_key] do
        nil -> []
        taxon -> [%{entry | taxon: taxon}]
      end
    end)
    |> roll_up(filter.species_only)
    |> sort(filter.sort)
    |> Location.Query.preload_all_locations()
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

  defp roll_up(entries, false), do: entries

  defp roll_up(entries, true) do
    entries
    |> Enum.flat_map(fn entry ->
      case Taxon.species(entry.taxon) do
        nil -> []
        species -> [%{entry | taxon: species}]
      end
    end)
    |> Enum.group_by(& &1.taxon.id)
    |> Enum.map(fn {_id, entries} -> Enum.min_by(entries, &first_record_key/1) end)
  end

  defp sort(entries, :taxonomy), do: Enum.sort_by(entries, & &1.taxon.sort_order)
  defp sort(entries, :date), do: Enum.sort_by(entries, &newest_first_key/1, :desc)

  # Matches `Query.first_records/2`: a missing start time sorts after any time.
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
