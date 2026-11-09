defmodule Kjogvi.Birding.TaxaLifelist.Query do
  @moduledoc """
  Queries to build the taxa lifelist.
  """

  import Ecto.Query

  alias Kjogvi.Birding.Lifelist

  @doc """
  The earliest observation of each taxon matching a book lifelist `filter`.
  """
  @spec first_records(Kjogvi.Scope.t(), Lifelist.Filter.t()) :: Ecto.Query.t()
  def first_records(scope, %Lifelist.Filter{book: %Ornitho.Schema.Book{}} = filter) do
    Lifelist.Query.observations_filtered(scope, filter)
    |> distinct([observation: o], o.taxon_key)
    |> order_by([observation: o, checklist: c],
      asc: o.taxon_key,
      asc: c.observ_date,
      asc_nulls_last: c.start_time,
      asc: o.id
    )
    |> select([observation: o, checklist: c], %{
      id: o.id,
      taxon_key: o.taxon_key,
      observ_date: c.observ_date,
      start_time: c.start_time,
      checklist_id: c.id,
      location_id: c.location_id
    })
  end
end
