defmodule Kjogvi.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: Kjogvi.Repo

  def location_factory do
    %Kjogvi.Birding.Location{
      slug: sequence(:slug, &"winnipeg#{&1}"),
      name_en: sequence(:slug, &"Winnipeg - #{&1}")
    }
  end

  def card_factory do
    %Kjogvi.Birding.Card{
      observ_date: "2023-08-29",
      effort_type: "INCIDENTAL",
      location: build(:location)
    }
  end

  def observation_factory do
    %Kjogvi.Birding.Observation{
      card: build(:card)
    }
  end
end
