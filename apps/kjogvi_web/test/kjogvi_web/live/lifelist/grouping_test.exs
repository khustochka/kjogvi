defmodule KjogviWeb.Live.Lifelist.GroupingTest do
  use ExUnit.Case, async: true

  alias Kjogvi.Birding.Lifelist.Filter
  alias Kjogvi.Birding.Lifelist.Result
  alias Kjogvi.Birding.LifeObservation
  alias Kjogvi.Pages.Species
  alias KjogviWeb.Live.Lifelist.Grouping

  defp lifer(opts) do
    %LifeObservation{
      observ_date: opts[:date],
      species_page: %Species{
        order: opts[:order],
        family: opts[:family]
      }
    }
  end

  defp result(list, filter \\ []) do
    %Result{
      list: list,
      total: length(list),
      filter: Filter.discombo!(filter)
    }
  end

  describe "by_taxonomy/1" do
    test "groups consecutive lifers by {order, family} and ranks them 1..N" do
      lifers = [
        lifer(order: "Anseriformes", family: "Anatidae"),
        lifer(order: "Anseriformes", family: "Anatidae"),
        lifer(order: "Passeriformes", family: "Corvidae"),
        lifer(order: "Passeriformes", family: "Paridae")
      ]

      assert [
               {{:taxonomy, "Anseriformes", "Anatidae"}, [{_, 1}, {_, 2}]},
               {{:taxonomy, "Passeriformes", "Corvidae"}, [{_, 3}]},
               {{:taxonomy, "Passeriformes", "Paridae"}, [{_, 4}]}
             ] = Grouping.by_taxonomy(result(lifers))
    end

    test "returns [] for an empty list" do
      assert Grouping.by_taxonomy(result([])) == []
    end

    test "produces separate groups when the same family is non-consecutive" do
      # Real lifelists have this case — sort_order interleaves families.
      lifers = [
        lifer(family: "Anatidae"),
        lifer(family: "Corvidae"),
        lifer(family: "Anatidae")
      ]

      groups = Grouping.by_taxonomy(result(lifers))
      assert length(groups) == 3
    end

    test "handles nil order/family" do
      lifers = [lifer(order: nil, family: nil)]

      assert [{{:taxonomy, nil, nil}, [{_, 1}]}] = Grouping.by_taxonomy(result(lifers))
    end
  end

  describe "by_year/1" do
    test "groups by year of observ_date and ranks N..1 (newest first)" do
      lifers = [
        lifer(date: ~D[2023-09-01]),
        lifer(date: ~D[2023-04-01]),
        lifer(date: ~D[2021-05-01])
      ]

      assert [
               {{:year, 2023}, [{_, 3}, {_, 2}]},
               {{:year, 2021}, [{_, 1}]}
             ] = Grouping.by_year(result(lifers))
    end

    test "returns a single :none group when filter.year is set" do
      lifers = [
        lifer(date: ~D[2023-04-01]),
        lifer(date: ~D[2023-09-01])
      ]

      assert [{:none, [{_, 2}, {_, 1}]}] =
               Grouping.by_year(result(lifers, year: 2023))
    end

    test "returns [] for an empty list" do
      assert Grouping.by_year(result([])) == []
    end

    test "treats nil observ_date as a :none group" do
      lifers = [lifer(date: nil)]

      assert [{:none, [{_, 1}]}] = Grouping.by_year(result(lifers))
    end
  end
end
