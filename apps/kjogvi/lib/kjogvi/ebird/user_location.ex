defmodule Kjogvi.Ebird.UserLocation do
  @moduledoc """
  A location as it appears in a user's eBird "Download My Data" export, keyed by
  eBird's own `ebird_loc_id` (e.g. `"L99381"`). One row per distinct location a
  user has records at; scoped to the owning user.

  Optionally mapped to a real `Kjogvi.Geo.Location` via `location_id` once the
  import has matched it; `nil` until then. Distinct from `Kjogvi.Geo.EbirdLocation`,
  which is eBird's region reference dataset shared across all users.
  """

  use Kjogvi.Schema

  import Ecto.Changeset

  alias Kjogvi.Accounts.User
  alias Kjogvi.Geo.Location

  schema "ebird_user_locations" do
    field :ebird_loc_id, :string
    field :name, :string
    field :state, :string
    field :county, :string
    field :lat, :decimal
    field :lon, :decimal

    belongs_to(:user, User)
    belongs_to(:location, Location)

    timestamps()
  end

  @castable_fields ~w(ebird_loc_id name state county lat lon user_id location_id)a

  @doc false
  def changeset(user_location, attrs) do
    user_location
    |> cast(attrs, @castable_fields)
    |> validate_required([:ebird_loc_id, :name, :user_id])
    |> unique_constraint([:user_id, :ebird_loc_id])
    |> assoc_constraint(:user)
    |> assoc_constraint(:location)
  end
end
