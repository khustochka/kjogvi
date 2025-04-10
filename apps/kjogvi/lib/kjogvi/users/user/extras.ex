defmodule Kjogvi.Users.User.Extras do
  @moduledoc """
  A schema representing user's extra settings.
  """

  use Kjogvi.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    embeds_one :ebird, Ebird, on_replace: :update, primary_key: false, defaults_to_struct: true do
      field :username, :string
      field :password, :string, redact: true
    end
  end

  def changeset(ebird, attrs) do
    ebird
    |> cast(attrs, [])
    |> cast_embed(:ebird, with: &ebird_changeset/2)
  end

  defp ebird_changeset(schema, params) do
    schema
    |> cast(params, [:username, :password])
  end
end
