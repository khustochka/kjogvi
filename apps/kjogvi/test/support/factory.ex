defmodule Kjogvi.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: Kjogvi.Repo

  def location_factory do
    %Kjogvi.Geo.Location{
      slug: sequence(:slug, &"winnipeg#{&1}"),
      name_en: sequence(:slug, &"Winnipeg - #{&1}")
    }
  end

  def card_factory do
    %Kjogvi.Birding.Card{
      user: Kjogvi.UsersFixtures.user_fixture(),
      observ_date: "2023-08-29",
      effort_type: "INCIDENTAL",
      location: build(:location)
    }
  end

  def main_user_card_factory do
    struct!(
      card_factory(),
      %{user: Kjogvi.Settings.main_user()}
    )
  end

  def observation_factory do
    %Kjogvi.Birding.Observation{
      card: build(:card),
      # For spuhs and subspecies this needs to be explicitly set.
      cached_species_key: fn obs -> obs.taxon_key end
    }
  end
end
