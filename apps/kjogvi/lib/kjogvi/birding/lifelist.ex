defmodule Kjogvi.Birding.Lifelist do
  @moduledoc """
  Lifelist generation.
  """

  import Ecto.Query

  alias Kjogvi.Repo

  alias Kjogvi.Birding.Card
  alias Kjogvi.Birding.LifeObservation
  alias Kjogvi.Birding.Observation
  alias Kjogvi.Geo

  def generate(params \\ %{}) do
    lifelist_query(params)
    |> Repo.all()
    |> Enum.map(&Repo.load(LifeObservation, &1))
    |> Repo.preload(location: :country)
    |> Kjogvi.Birding.preload_taxa_and_species()
    |> Enum.filter(fn rec -> rec.species end)
    |> Enum.uniq_by(fn rec -> rec.species.code end)
    |> Enum.reverse()
  end

  def years(params \\ %{}) do
    observations_filtered(params)
    |> distinct(true)
    |> select([..., c], type(fragment("EXTRACT(year from ?)", c.observ_date), :integer))
    |> Repo.all()
    |> Enum.sort()
  end

  def country_ids(params \\ %{}) do
    location_ids =
      observations_filtered(params)
      |> distinct(true)
      |> select([_o, c], [c.location_id])

    from(c in Kjogvi.Geo.Location)
    |> Geo.Location.Query.countries()
    |> join(:inner, [c], l in Kjogvi.Geo.Location, on: c.id == l.country_id or c.id == l.id)
    |> where([_c, l], l.id in subquery(location_ids))
    |> select([c], c.id)
    |> Repo.all()
  end

  def observations_filtered(params) do
    base = from([o, c] in observation_base())

    Enum.reduce(params, base, fn filter, query ->
      case filter do
        {:year, year} when not is_nil(year) ->
          Card.Query.by_year(query, year)

        {:location, location} when not is_nil(location) ->
          Card.Query.by_location_with_descendants(query, location)

        _ ->
          query
      end
    end)
  end

  defp lifelist_query(params) do
    from l in subquery(lifers_query(params)),
      order_by: [asc: l.observ_date, asc_nulls_last: l.start_time, asc: l.id]
  end

  defp lifers_query(params) do
    from [o, c] in observations_filtered(params),
      distinct: o.taxon_key,
      order_by: [asc: o.taxon_key, asc: c.observ_date, asc_nulls_last: c.start_time, asc: o.id],
      select: %{
        id: o.id,
        card_id: c.id,
        taxon_key: o.taxon_key,
        observ_date: c.observ_date,
        start_time: c.start_time,
        location_id: c.location_id
      }
  end

  defp observation_base do
    from o in Observation,
      join: c in assoc(o, :card),
      where: o.unreported == false
  end
end
