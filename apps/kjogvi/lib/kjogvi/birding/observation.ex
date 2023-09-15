defmodule Kjogvi.Birding.Observation do
  @moduledoc """
  Observation schema.
  """

  use Kjogvi.Schema
  import Ecto.Changeset

  schema "observations" do
    belongs_to(:card, Kjogvi.Birding.Card)
    field :taxon_key, :string
    field :quantity, :string
    field :voice, :boolean, default: false
    field :notes, :string
    field :private_notes, :string
    field :unreported, :boolean, default: false
    field :ebird_obs_id, :string

    timestamps()

    field :taxon, :map, virtual: true
    field :species, :map, virtual: true
  end

  @doc false
  def changeset(card, attrs) do
    card
    |> cast(attrs, [])
    |> validate_required([
      :card_id,
      :taxon_key,
      :voice,
      :unreported
    ])
  end
end
