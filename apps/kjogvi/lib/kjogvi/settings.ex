defmodule Kjogvi.Settings do
  @moduledoc """
  Site-wide settings, feature flags, and kill switches.

  Each setting is exposed as its own intention-revealing function
  (e.g. `registration_disabled?/0`) so call sites read clearly and never depend
  on how the value is stored. Values are resolved through the private `get/2`:
  a row in the `admin_site_settings` table wins, then application config, then
  a hardcoded default:

      config :kjogvi, Kjogvi.Settings, registration_disabled: true

  Database lookups go through `Kjogvi.Cache`; `put_setting/2` writes a row and
  invalidates its cache entry.
  """

  alias Kjogvi.Repo
  alias Kjogvi.Settings.Setting

  # Backstop for evictions that can't reach this node's cache (writes only
  # invalidate locally); bounds how long a stale value can live.
  @cache_ttl :timer.minutes(5)

  @doc """
  Whether new user registration is closed.
  """
  def registration_disabled? do
    get(:registration_disabled, false)
  end

  @doc """
  Whether the forgot/reset password flow is closed.
  """
  def forgot_reset_password_disabled? do
    get(:forgot_reset_password_disabled, false)
  end

  @doc """
  Whether the email/account confirmation flow is closed.
  """
  def confirmation_disabled? do
    get(:confirmation_disabled, false)
  end

  @doc """
  The `Ornitho.Importer` module the bootstrap seeds taxonomy from.

  A module doesn't fit a JSON value, so this setting is config-only and never
  overridden from the database.
  """
  def default_taxonomy_importer do
    config_get(:default_taxonomy_importer, nil)
  end

  @doc """
  The site default taxonomy as a `"slug/version"` book signature. Stamped on
  new users at registration; existing users keep their signature when this
  changes. Falls back to the signature of `default_taxonomy_importer/0` when
  no database row overrides it; `nil` when neither is set.
  """
  def default_taxonomy do
    get(:default_taxonomy, importer_signature(default_taxonomy_importer()))
  end

  @doc """
  Stores a setting override in `admin_site_settings` (upsert by key) and
  invalidates its cache entry. An explicit `nil` value is an override too —
  it suppresses the config fallback rather than restoring it.
  """
  def put_setting(key, value) do
    result =
      %Setting{}
      |> Setting.changeset(%{key: to_string(key), value: value})
      |> Repo.insert(
        on_conflict: {:replace, [:value, :updated_at]},
        conflict_target: :key
      )

    Kjogvi.Cache.delete(cache_key(key))
    result
  end

  defp importer_signature(nil), do: nil
  defp importer_signature(importer), do: "#{importer.slug()}/#{importer.version()}"

  # Resolution layer: database row -> app config -> default.
  defp get(key, default) do
    case db_get(key) do
      {:ok, value} -> value
      :error -> config_get(key, default)
    end
  end

  # The row's absence (:error) is cached too, so unset settings don't
  # re-query on every call.
  defp db_get(key) do
    Kjogvi.Cache.fetch(
      cache_key(key),
      fn _ -> {:commit, db_read(key)} end,
      ttl: @cache_ttl
    )
  end

  defp db_read(key) do
    case Repo.get_by(Setting, key: to_string(key)) do
      nil -> :error
      %Setting{value: value} -> {:ok, value}
    end
  end

  defp config_get(key, default) do
    :kjogvi
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(key, default)
  end

  defp cache_key(key), do: "settings:#{key}"
end
