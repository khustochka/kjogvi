defmodule Kjogvi.Settings do
  @moduledoc """
  Site-wide settings, feature flags, and kill switches.

  The known settings are declared once in a `NimbleOptions` schema carrying each
  one's type, default, and display label. That roster backs both the readers here
  and the admin UI, which enumerates it (`keys/0`, `flag_keys/0`, `label/1`,
  `fetch/1`) rather than restating the settings; `key!/1` casts
  a client-supplied string to a known key, and `put_setting/2` validates against
  the schema, so an unknown key or a wrongly-typed value can't be stored.

  Each setting is also exposed as its own intention-revealing function
  (e.g. `registration_disabled?/0`) so call sites read clearly and never depend
  on how the value is stored. Values are resolved through the private `get/2`:
  a row in the `admin_site_settings` table wins, then application config, then
  the schema default:

      config :kjogvi, Kjogvi.Settings, registration_disabled: true

  Database lookups go through `Kjogvi.Cache`; `put_setting/2` writes a row and
  invalidates its cache entry.
  """

  alias Kjogvi.Repo
  alias Kjogvi.Settings.Setting

  # Backstop for evictions that can't reach this node's cache (writes only
  # invalidate locally); bounds how long a stale value can live.
  @cache_ttl :timer.minutes(5)

  # The setting roster. Flags are stored negatively (`<feature>_disabled`); the
  # `:doc` is the positive feature name the admin UI speaks in.
  @schema NimbleOptions.new!(
            registration_disabled: [type: :boolean, default: false, doc: "Registration"],
            forgot_reset_password_disabled: [
              type: :boolean,
              default: false,
              doc: "Password reset"
            ],
            email_confirmation_disabled: [
              type: :boolean,
              default: false,
              doc: "Email confirmation"
            ],
            default_taxonomy: [type: {:or, [:string, nil]}, default: nil, doc: "Default taxonomy"]
          )

  @flag_keys for {key, opts} <- @schema.schema, opts[:type] == :boolean, do: key

  @doc """
  The known setting keys.
  """
  def keys, do: Keyword.keys(@schema.schema)

  @doc """
  The boolean kill-switch keys, in roster order.
  """
  def flag_keys, do: @flag_keys

  @doc """
  Casts a client-supplied string to a known setting key, raising otherwise.
  """
  def key!(key) when is_binary(key) do
    Enum.find(keys(), &(to_string(&1) == key)) ||
      raise ArgumentError, "unknown setting #{inspect(key)}"
  end

  @doc """
  The display name of `key`: for a flag, the positive feature it switches
  (`:forgot_reset_password_disabled` -> `"Password reset"`).
  """
  def label(key), do: @schema.schema[key][:doc]

  @doc """
  The current value of any setting by key, resolved override → config → default.
  """
  def fetch(key) do
    get(key, @schema.schema[key][:default])
  end

  @doc """
  Whether new user registration is closed.
  """
  def registration_disabled? do
    fetch(:registration_disabled)
  end

  @doc """
  Whether the forgot/reset password flow is closed.
  """
  def forgot_reset_password_disabled? do
    fetch(:forgot_reset_password_disabled)
  end

  @doc """
  Whether the email/account confirmation flow is closed.
  """
  def email_confirmation_disabled? do
    fetch(:email_confirmation_disabled)
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
  The stored override for `key`: `{:ok, value}` when a row exists (even one
  holding `nil`), `:error` when the setting falls through to config.
  """
  def get_override(key) do
    db_get(key)
  end

  @doc """
  Stores a setting override in `admin_site_settings` (upsert by key) and
  invalidates its cache entry. An explicit `nil` value is an override too —
  it suppresses the config fallback rather than restoring it.
  """
  def put_setting(key, value) do
    NimbleOptions.validate!([{key, value}], @schema)

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

  @doc """
  Removes the override row for `key`, restoring the config/default fallback,
  and invalidates its cache entry.
  """
  def delete_setting(key) do
    case Repo.get_by(Setting, key: to_string(key)) do
      nil -> :ok
      setting -> Repo.delete!(setting)
    end

    Kjogvi.Cache.delete(cache_key(key))
    :ok
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
