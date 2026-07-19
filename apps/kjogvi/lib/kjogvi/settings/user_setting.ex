defmodule Kjogvi.Settings.UserSetting do
  @moduledoc """
  An admin-set per-user setting, stored as a key/value row in
  `admin_user_settings`.

  Rows are overrides: a user without a row for a key falls back to the schema
  default (see `Kjogvi.Settings.User`). These are set by administrators, not by
  the user themselves — user-owned preferences live in
  `Kjogvi.Accounts.UserPreferences`.
  """

  use Kjogvi.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "admin_user_settings" do
    field :key, :string
    field :value, Kjogvi.Settings.Setting.Value

    belongs_to :user, Kjogvi.Accounts.User

    timestamps()
  end

  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:user_id, :key, :value])
    |> validate_required([:user_id, :key])
    |> unique_constraint([:user_id, :key])
  end
end
