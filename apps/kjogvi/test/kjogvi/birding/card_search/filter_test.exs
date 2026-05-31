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
