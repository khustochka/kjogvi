defmodule Kjogvi.Birding.Observation do
  @moduledoc """
  Observation schema.
  """

  use Kjogvi.Schema

  import Ecto.Changeset

  alias Kjogvi.Pages.SpeciesTaxaMapping

  schema "observations" do
    belongs_to(:card, Kjogvi.Birding.Card)
    field :taxon_key, :string
    field :quantity, :string
    field :voice, :boolean, default: false
    field :notes, :string
    field :private_notes, :string
    # Hidden from public, but shown to the owner
    field :hidden, :boolean, default: false
    # Not included in lifelist even for the owner
    field :unreported, :boolean, default: false
    field :ebird_obs_id, :string

    belongs_to :species_taxa_mapping, SpeciesTaxaMapping,
      foreign_key: :taxon_key,
      references: :taxon_key,
      define_field: false

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
end
