defmodule Kjogvi.GeoFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Kjogvi.Geo` context.
  """

  alias Kjogvi.Geo.Location
  alias Kjogvi.Repo
  import Ecto.Changeset

  def unique_location_slug, do: "location-#{System.unique_integer()}"

  def valid_location_attributes(attrs \\ %{}) do
    default_attrs = %{
      slug: unique_location_slug(),
      name_en: "Test Location #{System.unique_integer()}",
      location_type: "unknown",
      ancestry: [],
      is_private: false,
      is_patch: false,
      is_5mr: false
    }

    Enum.into(attrs, default_attrs)
  end

  def location_fixture(attrs \\ %{}) do
    attrs_with_defaults = valid_location_attributes(attrs)

    {:ok, location} =
      %Location{}
      |> cast(attrs_with_defaults, [
        :slug,
        :name_en,
        :location_type,
        :ancestry,
        :is_private,
        :is_patch,
        :is_5mr
      ])
      |> validate_required([:slug, :name_en, :ancestry, :is_private, :is_patch, :is_5mr])
      |> Repo.insert()

    location
  end
end
