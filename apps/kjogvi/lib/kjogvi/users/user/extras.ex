defmodule Kjogvi.Users.User.Extras do
  @moduledoc """
  A schema representing user's extra settings.
  """

  use Kjogvi.Schema
  import Ecto.Changeset

  alias Kjogvi.Users.User.Extras.LogSetting

  @primary_key false
  embedded_schema do
    embeds_one :ebird, Ebird, on_replace: :update, primary_key: false, defaults_to_struct: true do
      field :username, :string
      field :password, :string, redact: true
    end

    embeds_many :log_settings, LogSetting, on_replace: :delete
  end

  def changeset(extras, attrs) do
    extras
    |> cast(attrs, [])
    |> cast_embed(:ebird, with: &ebird_changeset/2)
    |> cast_embed(:log_settings)
  end

  defp ebird_changeset(schema, params) do
    schema
    |> cast(params, [:username, :password])
  end
end
