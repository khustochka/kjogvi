defmodule Kjogvi.Accounts.UserPreferences do
  @moduledoc """
  Behavioral per-user settings: eBird sync credentials and logbook settings.

  A row is created lazily on the first preferences save; users without one are
  represented by a default struct (see `Kjogvi.Accounts.get_user_preferences/1`).
  """

  use Kjogvi.Schema
  import Ecto.Changeset

  alias Kjogvi.Accounts.UserPreferences.LogbookSetting

  @type t :: %__MODULE__{}

  schema "user_preferences" do
    embeds_one :ebird, Ebird, on_replace: :update, primary_key: false, defaults_to_struct: true do
      field :username, :string
      field :password, :string, redact: true
    end

    embeds_many :logbook_settings, LogbookSetting, on_replace: :delete

    belongs_to :user, Kjogvi.Accounts.User

    timestamps()
  end

  def changeset(preferences, attrs) do
    preferences
    |> cast(attrs, [])
    |> cast_embed(:ebird, with: &ebird_changeset/2)
    |> cast_embed(:logbook_settings)
  end

  defp ebird_changeset(ebird, attrs) do
    ebird
    |> cast(attrs, [:username, :password])
  end

  @doc """
  Whether the user is configured for sync eBird update: has username, can ask for password.
  """
  def ebird_configured_sync?(%__MODULE__{} = preferences) do
    not is_nil(preferences.ebird.username)
  end

  @doc """
  Whether the user is configured for async eBird update: has username and password.
  """
  def ebird_configured_async?(%__MODULE__{} = preferences) do
    not is_nil(preferences.ebird.username) &&
      not is_nil(preferences.ebird.password)
  end
end
