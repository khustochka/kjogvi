defmodule Kjogvi.Geo.Ebird do
  @moduledoc """
  The eBird regions reference dataset (`Kjogvi.Geo.EbirdLocation`): match
  status aggregation and the manual resolution operations — linking eBird
  regions to common locations, unlinking, and creating a common location from
  an eBird region.

  Matching passes live in `Kjogvi.Geo.Ebird.Matcher`; the bootstrap import in
  `Kjogvi.Geo.Ebird.Import`.
  """

  alias Kjogvi.Geo.EbirdLocation
  alias Kjogvi.Geo.Location
  alias Kjogvi.Repo

  defdelegate match_country(country_code, opts \\ []), to: Kjogvi.Geo.Ebird.Matcher

  @doc """
  A map of `location_type => %{total: n, matched: n}` over the eBird locations
  dataset, where matched rows are those linked to a common location.
  """
  def location_counts_by_type do
    EbirdLocation.Query.count_by_type_with_matched()
    |> Repo.all()
    |> Map.new(fn {type, total, matched} -> {type, %{total: total, matched: matched}} end)
  end

  @doc """
  Match stats and derived status for every eBird country, keyed by country
  code. Each entry carries `:status` (see
  `Kjogvi.Geo.EbirdLocation.Query.derive_status/1`) plus the underlying
  counts: `country_linked`, `country_code_match`, `sub1_total`, `sub1_linked`,
  `sub1_code_matched`, `iso_sub1_total`, `iso_extra`.
  """
  def country_statuses do
    statuses_from(EbirdLocation)
  end

  @doc """
  The `country_statuses/0` entry for one country, or nil if the country code
  is unknown.
  """
  def country_status(country_code) do
    EbirdLocation
    |> EbirdLocation.Query.for_country(country_code)
    |> statuses_from()
    |> Map.get(country_code)
  end

  @doc """
  Every eBird country row ordered by code, each as
  `%{ebird_location: row, stats: stats}` with its `country_statuses/0` entry —
  the admin index data.
  """
  def countries_with_statuses do
    statuses = country_statuses()

    EbirdLocation
    |> EbirdLocation.Query.countries()
    |> EbirdLocation.Query.order_by_code()
    |> Repo.all()
    |> Enum.map(&%{ebird_location: &1, stats: Map.fetch!(statuses, &1.country_code)})
  end

  @doc """
  The eBird country row for `country_code`, with its linked common location
  preloaded, or nil.
  """
  def get_country(country_code) do
    EbirdLocation
    |> EbirdLocation.Query.for_country(country_code)
    |> EbirdLocation.Query.countries()
    |> EbirdLocation.Query.preload_location()
    |> Repo.one()
  end

  @doc """
  The country's matchable eBird rows (the country row and its subdivision1s)
  ordered by code — the country row first — with linked common locations and
  their level associations preloaded for display names.
  """
  def matchable_locations(country_code) do
    EbirdLocation
    |> EbirdLocation.Query.for_country(country_code)
    |> EbirdLocation.Query.matchable()
    |> EbirdLocation.Query.order_by_code()
    |> EbirdLocation.Query.preload_location()
    |> Repo.all()
  end

  @doc """
  The linked common country's subdivision1s that no eBird row points at —
  ISO-only subdivisions (the Hungary case), listed in the workbench for
  context. Empty when the eBird country row is not linked.
  """
  def unmatched_iso_subdivision1s(country_code) do
    case get_country(country_code) do
      %EbirdLocation{location_id: location_id} when not is_nil(location_id) ->
        location_id
        |> EbirdLocation.Query.unlinked_common_subdivision1s()
        |> Location.Query.order_by_name()
        |> Repo.all()

      _ ->
        []
    end
  end

  @doc """
  Links an unlinked eBird region to the common location with `location_id`.

  Returns `{:error, :already_linked}` when the region is linked (unlink
  first), `{:error, :not_common}` for a user-owned location, `{:error,
  :not_found}` for an unknown id, and `{:error, changeset}` when the location
  is already linked from another eBird row (unique constraint).
  """
  def link(%EbirdLocation{} = ebird_location, location_id) do
    case Repo.reload!(ebird_location) do
      %EbirdLocation{location_id: nil} = fresh ->
        do_link(fresh, Repo.get(Location, location_id))

      _linked ->
        {:error, :already_linked}
    end
  end

  defp do_link(_ebird_location, nil), do: {:error, :not_found}

  defp do_link(%EbirdLocation{} = ebird_location, %Location{user_id: nil} = location) do
    ebird_location
    |> EbirdLocation.changeset(%{location_id: location.id})
    |> Repo.update()
  end

  defp do_link(_ebird_location, %Location{}), do: {:error, :not_common}

  @doc """
  Clears an eBird region's link to a common location.
  """
  def unlink(%EbirdLocation{} = ebird_location) do
    ebird_location
    |> EbirdLocation.changeset(%{location_id: nil})
    |> Repo.update()
  end

  @doc """
  Creates a common location from an unlinked eBird region and links the region
  to it — how eBird-only regions enter the common dataset.

  Name from the region's `name`; slug from the eBird code (downcased,
  `-` → `_`, the ISO import's scheme); `import_source: :ebird_regions`;
  `iso_code` stays nil (an eBird code is not an ISO code). A subdivision1 is
  placed under the common country its eBird country row is linked to —
  `{:error, :country_not_linked}` when there is none yet.

  Returns the created location, `{:error, :already_linked}` when the region is
  already linked, or `{:error, changeset}` on a slug collision.
  """
  def create_common_location(%EbirdLocation{} = ebird_location) do
    case Repo.reload!(ebird_location) do
      %EbirdLocation{location_id: nil} = fresh -> do_create_common_location(fresh)
      _linked -> {:error, :already_linked}
    end
  end

  defp do_create_common_location(%EbirdLocation{location_type: :country} = ebird_location) do
    insert_and_link(ebird_location, nil)
  end

  defp do_create_common_location(%EbirdLocation{location_type: :subdivision1} = ebird_location) do
    case get_country(ebird_location.country_code) do
      %EbirdLocation{location: %Location{} = parent} -> insert_and_link(ebird_location, parent)
      _ -> {:error, :country_not_linked}
    end
  end

  defp insert_and_link(ebird_location, parent) do
    Repo.transact(fn ->
      with {:ok, location} <- insert_common_location(ebird_location, parent),
           {:ok, _linked} <-
             ebird_location
             |> EbirdLocation.changeset(%{location_id: location.id})
             |> Repo.update() do
        {:ok, location}
      end
    end)
  end

  # Built with a bare `change/1` rather than `Location.changeset/2`: the
  # dataset shares the ISO import's code-derived slug scheme, and a country
  # code makes a two-letter slug — below the user-facing minimum the changeset
  # enforces (the ISO import bypasses it via `insert_all` the same way).
  defp insert_common_location(ebird_location, parent) do
    %Location{}
    |> Ecto.Changeset.change(
      slug: slug_from_code(ebird_location.code),
      name_en: ebird_location.name,
      location_type: ebird_location.location_type,
      is_private: false,
      import_source: :ebird_regions
    )
    |> Ecto.Changeset.change(parent_level_fks(parent))
    |> Ecto.Changeset.unique_constraint(:slug, name: :locations_common_slug_index)
    |> Repo.insert()
  end

  defp parent_level_fks(nil), do: []

  defp parent_level_fks(parent) do
    parent
    |> Location.level_fks_from_parent()
    |> Enum.reject(fn {_fk, value} -> is_nil(value) end)
  end

  defp slug_from_code(code) do
    code |> String.downcase() |> String.replace("-", "_")
  end

  defp statuses_from(base) do
    sub1 =
      base
      |> EbirdLocation.Query.sub1_match_stats()
      |> Repo.all()
      |> Map.new(&{&1.country_code, &1})

    iso =
      base
      |> EbirdLocation.Query.iso_sub1_stats()
      |> Repo.all()
      |> Map.new(&{&1.country_code, &1})

    base
    |> EbirdLocation.Query.country_match_stats()
    |> Repo.all()
    |> Map.new(fn country ->
      stats =
        country
        |> Map.merge(
          Map.get(sub1, country.country_code, %{
            sub1_total: 0,
            sub1_linked: 0,
            sub1_code_matched: 0
          })
        )
        |> Map.merge(Map.get(iso, country.country_code, %{iso_sub1_total: 0, iso_extra: 0}))

      {country.country_code, Map.put(stats, :status, EbirdLocation.Query.derive_status(stats))}
    end)
  end
end
