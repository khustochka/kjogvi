defmodule Kjogvi.Geo.EbirdLocation do
  @moduledoc """
  An eBird location reference: a country, subnational1, or subnational2 region as
  defined by eBird, keyed by eBird's own `code` (the canonical region code, e.g.
  `"CA-AB-EI"`). This is reference data imported from eBird, distinct from the
  `Kjogvi.Ebird.Web` client.

  Optionally mapped 1-to-1 to a `Kjogvi.Geo.Location` via `location_id`; the
  mapping may be `nil` when no local location corresponds to the eBird region.
  """

  use Kjogvi.Schema

  import Ecto.Changeset

  alias Kjogvi.Geo.Location

  @location_types ~w(country subdivision1 subdivision2)a

  schema "ebird_locations" do
    field :code, :string
    field :location_type, Ecto.Enum, values: @location_types
    field :country_code, :string
    field :subnational1_code, :string
    field :subnational2_code, :string
    field :local_abbrev, :string
    field :name, :string
    field :name_long, :string
    field :name_short, :string
    field :nice_name, :string

    belongs_to(:location, Location)

    timestamps()
  end

  def location_types, do: @location_types

  @castable_fields ~w(
    code
    location_type
    country_code
    subnational1_code
    subnational2_code
    local_abbrev
    name
    name_long
    name_short
    nice_name
    location_id
  )a

  @doc false
  def changeset(ebird_location, attrs) do
    ebird_location
    |> cast(attrs, @castable_fields)
    |> validate_required([:code, :location_type])
    |> unique_constraint(:code)
    |> unique_constraint(:location_id)
    |> assoc_constraint(:location)
  end
end
