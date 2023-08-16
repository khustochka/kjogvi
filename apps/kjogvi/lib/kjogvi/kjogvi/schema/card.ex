defmodule Kjogvi.Kjogvi.Schema.Card do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cards" do


    timestamps()
  end

  @doc false
  def changeset(card, attrs) do
    card
    |> cast(attrs, [])
    |> validate_required([])
  end
end
