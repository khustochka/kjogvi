defmodule Kjogvi.Birding.Observation do
  @moduledoc """
  Observation schema.
  """

  use Kjogvi.Schema
  import Ecto.Changeset

  schema "observations" do
    belongs_to(:card, Kjogvi.Birding.Card)
    field :taxon_key, :string
    field :cached_species_key, :string
    field :quantity, :string
    field :voice, :boolean, default: false
    field :notes, :string
    field :private_notes, :string
    # Hidden from public, but shown to the owner
    field :hidden, :boolean, default: false
    # Not included in lifelist even for the owner
    field :unreported, :boolean, default: false
    field :ebird_obs_id, :string

    timestamps()

    field :taxon, :map, virtual: true
    field :species, :map, virtual: true
  end

  @doc false
  def changeset(observation, attrs) do
    observation
    |> cast(attrs, [])
    |> validate_required([
      :card_id,
      :taxon_key,
      :voice,
      :unreported
    ])
  end

  def cache_species_changeset(observation, attrs) do
    observation
    |> cast(attrs, [:cached_species_key])
  end
end
