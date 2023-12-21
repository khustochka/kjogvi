defmodule Kjogvi.Birding.Lifelist do
  @moduledoc """
  Lifelist generation.
  """

  import Ecto.Query

  alias Kjogvi.Repo

  alias Kjogvi.Birding.Observation
  alias Kjogvi.Birding.LifeObservation

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
    |> select(fragment("EXTRACT(year from observ_date)::integer"))
    |> Repo.all()
    |> Enum.sort()
  end

  # def countries(params \\ %{}) do
  #   observations_filtered(params)
  #   |> distinct(true)
  #   |> select([_, c], c.location_id)
  #   |> Repo.all()
  # end

  def observations_filtered(params) do
    base = from [o, c] in observation_base()

    Enum.reduce(params, base, fn {k, val}, query ->
      case k do
        :year when not is_nil(val) ->
          filter_by_year(query, val)

        :location when not is_nil(val) ->
          filter_by_location(query, val)

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

  defp filter_by_year(query, year) do
    query
    |> where(fragment("EXTRACT(year from observ_date)::integer = ?", ^year))
  end

  defp filter_by_location(query, %{id: id, locus_type: "country"}) do
    from [_, c] in query,
      join: l in assoc(c, :location),
      where: l.country_id == ^id or l.id == ^id
  end

  defp filter_by_location(query, %{id: id}) do
    from [_, c] in query,
      join: l in assoc(c, :location),
      where: ^id in l.ancestry or l.id == ^id
  end
end
