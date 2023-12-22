defmodule Kjogvi.Geo do
  @moduledoc """
  Geography related functionality (countries, regions, locations).
  """

  import Ecto.Query

  alias Kjogvi.Repo
  alias Kjogvi.Query

  alias __MODULE__.Location

  def get_countries do
    Location
    |> where(location_type: "country")
    |> Repo.all()
  end

  def get_locations do
    Location
    |> Query.Location.load_cards_count()
    |> Repo.all()
  end

  def location_by_slug!(slug) do
    Location
    |> Query.Location.by_slug(slug)
    |> Repo.one!
  end
end
