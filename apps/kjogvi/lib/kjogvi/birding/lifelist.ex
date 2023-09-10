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
    |> Repo.preload(:location)
    |> Kjogvi.Birding.preload_taxa_and_species()
    |> Enum.filter(fn rec -> rec.species end)
    |> Enum.uniq_by(fn rec -> rec.species.code end)
  end

  def years(_params \\ %{}) do
    observation_base()
    |> distinct(true)
    |> select(fragment("EXTRACT(year from observ_date)::integer"))
    |> Repo.all()
    |> Enum.sort()
  end

  defp lifelist_query(params) do
    from l in subquery(lifers_query(params)),
      order_by: [desc: l.observ_date, desc_nulls_first: l.start_time, desc: l.id]
  end

  defp lifers_query(params) do
    base =
      from [o, c] in observation_base(),
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

    Enum.reduce(params, base, fn {k, val}, query ->
      case k do
        :year when not is_nil(val) ->
          query |> where(fragment("EXTRACT(year from observ_date)::integer = ?", ^val))

        _ ->
          query
      end
    end)
  end

  defp observation_base do
    from o in Observation,
      join: c in assoc(o, :card),
      where: o.unreported == false
  end
end
