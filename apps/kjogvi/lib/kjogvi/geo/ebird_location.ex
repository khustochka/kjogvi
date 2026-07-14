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
    field :name, :string

    belongs_to(:location, Location)

    timestamps()
  end

  def location_types, do: @location_types

  @doc """
  Whether the row's link is code-consistent: the linked location's `iso_code`
  equals the eBird code for the row's own level (§ "matched by code" — derived,
  never stored). False for unlinked rows; requires `location` to be preloaded
  on linked ones.
  """
  def code_match?(%__MODULE__{location_id: nil}), do: false

  def code_match?(%__MODULE__{location_type: :country} = ebird_location) do
    ebird_location.location.iso_code == ebird_location.code
  end

  def code_match?(%__MODULE__{location_type: :subdivision1} = ebird_location) do
    ebird_location.location.iso_code == ebird_location.subnational1_code
  end

  @castable_fields ~w(
    code
    location_type
    country_code
    subnational1_code
    subnational2_code
    name
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
