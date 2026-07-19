defmodule Kjogvi.Settings.Setting do
  @moduledoc """
  A site-wide setting stored as a key/value row in `admin_site_settings`.

  Rows are overrides: a setting without a row falls back to application config
  (see `Kjogvi.Settings`). The value is any JSON-representable term; a row with
  a `nil` value is an explicit override to `nil`, not a fallback.
  """

  use Kjogvi.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "admin_site_settings" do
    field :key, :string
    field :value, Kjogvi.Settings.Setting.Value

    timestamps()
  end

  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:key, :value])
    |> validate_required([:key])
    |> unique_constraint(:key)
  end
end
