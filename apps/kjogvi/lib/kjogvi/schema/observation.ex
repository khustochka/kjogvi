defmodule Kjogvi.Schema.Observation do
  use Kjogvi.Schema
  import Ecto.Changeset

  schema "observations" do
    belongs_to(:card, Kjogvi.Schema.Card)
    field :taxon_key, :string
    field :quantity, :string
    field :voice, :boolean, default: false
    field :notes, :string
    field :private_notes, :string
    belongs_to(:patch, Kjogvi.Schema.Location)
    field :unreported, :boolean, default: false
    field :ebird_obs_id, :string

    timestamps()
  end

  @doc false
  def changeset(card, attrs) do
    card
    |> cast(attrs, [])
    |> validate_required([])
  end
end
