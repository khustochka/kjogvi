defmodule KjogviWeb.Live.Lifelist.Grouping do
  @moduledoc """
  Shapes a `Kjogvi.Birding.Lifelist.Result` into render-ready groups for the
  lifelist view.

  Each group has the form `{header, [{lifer, rank}, ...]}` where `header` is
  one of:

    * `{:taxonomy, order, family}` — taxonomy-sorted group.
    * `{:year, year}` — first-record-year group.
    * `:none` — render no header (single implicit group).
  """

  alias Kjogvi.Birding.Lifelist.Result

  @type rank :: pos_integer()
  @type lifer :: map()
  @type header ::
          {:taxonomy, String.t() | nil, String.t() | nil}
          | {:year, integer()}
          | :none
  @type group :: {header(), [{lifer(), rank()}]}

  @spec by_taxonomy(Result.t()) :: [group()]
  def by_taxonomy(%Result{list: list}) do
    list
    |> Enum.with_index(fn lifer, i -> {lifer, i + 1} end)
    |> Enum.chunk_by(fn {lifer, _rank} ->
      {lifer.species_page.order, lifer.species_page.family}
    end)
    |> Enum.map(fn [{first, _} | _] = chunk ->
      sp = first.species_page
      {{:taxonomy, sp.order, sp.family}, chunk}
    end)
  end

  @spec by_year(Result.t()) :: [group()]
  def by_year(%Result{filter: %{year: year}, list: list, total: total})
      when not is_nil(year) do
    [{:none, Enum.with_index(list, fn lifer, i -> {lifer, total - i} end)}]
  end

  def by_year(%Result{list: list, total: total}) do
    list
    |> Enum.with_index(fn lifer, i -> {lifer, total - i} end)
    |> Enum.chunk_by(fn {lifer, _rank} ->
      lifer.observ_date && lifer.observ_date.year
    end)
    |> Enum.map(fn [{first, _} | _] = chunk ->
      case first.observ_date && first.observ_date.year do
        nil -> {:none, chunk}
        year -> {{:year, year}, chunk}
      end
    end)
  end
end
