defmodule Kjogvi.Birding.CardSearch.FilterTest do
  use ExUnit.Case, async: true

  alias Kjogvi.Birding.CardSearch.Filter

  describe "defaults" do
    test "a bare struct is blank and in card mode" do
      filter = %Filter{}

      assert filter.voice == :all
      refute filter.exclude_subspecies
      refute filter.hidden
      assert Filter.blank?(filter)
      refute Filter.observation_mode?(filter)
    end
  end

  describe "observation_mode?/1" do
    test "true when a taxon is set" do
      assert Filter.observation_mode?(%Filter{taxon_key: "/ebird/v2024/houspa"})
    end

    test "true when exclude_subspecies is on" do
      assert Filter.observation_mode?(%Filter{exclude_subspecies: true})
    end

    test "true when voice is not :all" do
      assert Filter.observation_mode?(%Filter{voice: :heard_only})
      assert Filter.observation_mode?(%Filter{voice: :seen})
    end

    test "true when hidden is on" do
      assert Filter.observation_mode?(%Filter{hidden: true})
    end

    test "false for card-level-only filters" do
      refute Filter.observation_mode?(%Filter{date: ~D[2024-01-01]})
      refute Filter.observation_mode?(%Filter{include_subregions: true})
    end
  end

  describe "blank?/1" do
    test "false once any filter is set" do
      refute Filter.blank?(%Filter{date: ~D[2024-01-01]})
      refute Filter.blank?(%Filter{voice: :seen})
    end
  end

  describe "to_params/1" do
    test "a blank filter yields an empty map" do
      assert Filter.to_params(%Filter{}) == %{}
    end

    test "emits only the non-default fields" do
      filter = %Filter{
        date: ~D[2024-05-01],
        include_subregions: true,
        taxon_key: "/ebird/v2024/houspa",
        exclude_subspecies: true,
        voice: :heard_only,
        hidden: true
      }

      assert Filter.to_params(filter) == %{
               "date" => "2024-05-01",
               "include_subregions" => "true",
               "taxon_key" => "/ebird/v2024/houspa",
               "exclude_subspecies" => "true",
               "voice" => "heard_only",
               "hidden" => "true"
             }
    end

    test "encodes the location as its id" do
      filter = %Filter{location: %Kjogvi.Geo.Location{id: 42}}

      assert Filter.to_params(filter) == %{"location_id" => "42"}
    end

    test "omits voice when it is :all" do
      refute Map.has_key?(Filter.to_params(%Filter{voice: :all}), "voice")
    end
  end

  describe "from_params/1" do
    test "an empty map decodes to a blank filter with no location_id" do
      assert {%Filter{} = filter, nil} = Filter.from_params(%{})
      assert Filter.blank?(filter)
    end

    test "round-trips a fully-populated filter (location aside)" do
      original = %Filter{
        date: ~D[2024-05-01],
        include_subregions: true,
        taxon_key: "/ebird/v2024/houspa",
        exclude_subspecies: true,
        voice: :seen,
        hidden: true
      }

      {decoded, nil} = original |> Filter.to_params() |> Filter.from_params()

      assert decoded == original
    end

    test "returns the location_id separately for the caller to resolve" do
      {%Filter{location: nil}, "42"} = Filter.from_params(%{"location_id" => "42"})
    end

    test "falls back to defaults on malformed values" do
      {filter, nil} = Filter.from_params(%{"date" => "not-a-date", "voice" => "bogus"})

      assert is_nil(filter.date)
      assert filter.voice == :all
    end
  end

  describe "discombo!/1" do
    test "validates and fills defaults" do
      filter = Filter.discombo!(voice: :seen)
      assert filter.voice == :seen
      assert filter.exclude_subspecies == false
    end

    test "raises on invalid voice" do
      assert_raise NimbleOptions.ValidationError, fn ->
        Filter.discombo!(voice: :whistled)
      end
    end
  end
end
