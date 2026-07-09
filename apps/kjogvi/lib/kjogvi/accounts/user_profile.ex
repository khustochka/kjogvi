defmodule Kjogvi.Accounts.UserProfile do
  @moduledoc """
  Public-facing per-user profile data: about text, country, external profile
  links and birding-since year.

  A row is created lazily on the first profile save (via `cast_assoc` on the
  user); users without one are represented by a bare struct.
  """

  use Kjogvi.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @about_max_length 2000
  @earliest_birding_year 1900

  schema "user_profiles" do
    field :about, :string
    field :country, :string
    field :ebird_profile_url, :string
    field :website_url, :string
    field :birding_since, :integer

    belongs_to :user, Kjogvi.Accounts.User

    timestamps()
  end

  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [:about, :country, :ebird_profile_url, :website_url, :birding_since])
    |> validate_length(:about, max: @about_max_length)
    |> validate_format(:country, ~r/^[A-Z]{2}$/, message: "must be a two-letter ISO country code")
    |> validate_url(:ebird_profile_url)
    |> validate_url(:website_url)
    |> validate_number(:birding_since,
      greater_than_or_equal_to: @earliest_birding_year,
      less_than_or_equal_to: Date.utc_today().year
    )
  end

  defp validate_url(changeset, field) do
    validate_change(changeset, field, fn ^field, value ->
      case URI.new(value) do
        {:ok, %URI{scheme: scheme, host: host}}
        when scheme in ["http", "https"] and is_binary(host) and host != "" ->
          []

        _ ->
          [{field, "must be a valid http(s) URL"}]
      end
    end)
  end
end
