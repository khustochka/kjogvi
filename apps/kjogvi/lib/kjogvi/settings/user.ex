defmodule Kjogvi.Settings.User do
  @moduledoc """
  Per-user settings set by administrators.

  Mirrors `Kjogvi.Settings`: the roster is declared once in a `NimbleOptions`
  schema carrying each setting's type, default, and display label, and backs both
  the readers here and the admin UI (`keys/0`, `label/1`, `fetch/2`). `key!/1`
  casts a client-supplied string to a known key, and `put/3` validates against
  the schema, so an unknown key or a wrongly-typed value can't be stored.

  Unlike site settings there is no config layer — a per-user value can't be
  expressed in config — so resolution is a row in `admin_user_settings`, then the
  schema default. Lookups go through `Kjogvi.Cache`; `put/3` and `delete/2`
  invalidate the affected entry.

  These are administrative flags, distinct from the user's own preferences in
  `Kjogvi.Accounts.UserPreferences`.
  """

  alias Kjogvi.Repo
  alias Kjogvi.Settings.UserSetting

  # Backstop for evictions that can't reach this node's cache (writes only
  # invalidate locally); bounds how long a stale value can live.
  @cache_ttl :timer.minutes(5)

  # Flags are stored negatively (`<feature>_disabled`); the `:doc` is the
  # positive feature name the admin UI speaks in.
  @schema NimbleOptions.new!(login_disabled: [type: :boolean, default: false, doc: "Login"])

  @doc """
  The known per-user setting keys.
  """
  def keys, do: Keyword.keys(@schema.schema)

  @doc """
  Casts a client-supplied string to a known setting key, raising otherwise.
  """
  def key!(key) when is_binary(key) do
    Enum.find(keys(), &(to_string(&1) == key)) ||
      raise ArgumentError, "unknown user setting #{inspect(key)}"
  end

  @doc """
  The display name of `key`: for a flag, the positive feature it switches
  (`:login_disabled` -> `"Login"`).
  """
  def label(key), do: @schema.schema[key][:doc]

  @doc """
  The current value of `key` for `user`, resolved override → default.
  """
  def fetch(user, key) do
    case db_get(user, key) do
      {:ok, value} -> value
      :error -> @schema.schema[key][:default]
    end
  end

  @doc """
  Whether the user is barred from logging in.
  """
  def login_disabled?(user) do
    fetch(user, :login_disabled)
  end

  @doc """
  Stores a per-user override (upsert by user and key) and invalidates its cache
  entry.
  """
  def put(user, key, value) do
    NimbleOptions.validate!([{key, value}], @schema)

    result =
      %UserSetting{}
      |> UserSetting.changeset(%{user_id: user.id, key: to_string(key), value: value})
      |> Repo.insert(
        on_conflict: {:replace, [:value, :updated_at]},
        conflict_target: [:user_id, :key]
      )

    Kjogvi.Cache.delete(cache_key(user, key))
    result
  end

  @doc """
  Removes the override row for `key`, restoring the default, and invalidates its
  cache entry.
  """
  def delete(user, key) do
    case Repo.get_by(UserSetting, user_id: user.id, key: to_string(key)) do
      nil -> :ok
      setting -> Repo.delete!(setting)
    end

    Kjogvi.Cache.delete(cache_key(user, key))
    :ok
  end

  # The row's absence (:error) is cached too, so unset settings don't
  # re-query on every call.
  defp db_get(user, key) do
    Kjogvi.Cache.fetch(
      cache_key(user, key),
      fn _ -> {:commit, db_read(user, key)} end,
      ttl: @cache_ttl
    )
  end

  defp db_read(user, key) do
    case Repo.get_by(UserSetting, user_id: user.id, key: to_string(key)) do
      nil -> :error
      %UserSetting{value: value} -> {:ok, value}
    end
  end

  defp cache_key(user, key), do: "user_settings:#{user.id}:#{key}"
end
