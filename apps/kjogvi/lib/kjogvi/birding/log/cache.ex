defmodule Kjogvi.Birding.Log.Cache do
  @moduledoc """
  Cache layer for `Kjogvi.Birding.Log.recent_entries/2`.

  Recomputing the recent-additions feed is expensive (it scans every
  observation a user has), but the result only changes when an observation
  or the user's `log_settings` changes. We cache one entry per
  `(user_id, limit, cutoff_days, today)` tuple. Including the current
  date in the key ensures stale results don't survive day boundaries.

  Only the public feed is cached. The private view (site owner viewing
  their own data, `include_private: true`) is a single-user code path
  with negligible cache benefit and is computed directly on every call.

  Invalidation enumerates all known variants for a user. The set of
  variants is small (each call site uses a fixed `(limit, cutoff_days)`
  tuple) and is listed explicitly in `cache_keys_for_user/1`.
  """

  @prefix "birding:log:user:"

  # 24h backstop so abandoned keys (e.g. previous days) eventually evict
  # themselves even if invalidation is missed.
  @ttl :timer.hours(24)

  @doc """
  Returns the cached value for `key_parts`, computing it via `fallback/0`
  on miss. `key_parts` is a tuple of `(user_id, limit, cutoff_days)`.
  """
  def fetch({user_id, limit, cutoff_days}, fallback)
      when is_function(fallback, 0) do
    key = build_key(user_id, limit, cutoff_days, Date.utc_today())

    Kjogvi.Cache.fetch(
      key,
      fn _ -> {:commit, fallback.()} end,
      ttl: @ttl
    )
  end

  @doc """
  Evicts every known cache entry for the given user. Call this from any
  write path that could change what `Log.recent_entries/2` would return:
  observation/card writes and `log_settings` updates.
  """
  def invalidate(user_id) do
    for key <- cache_keys_for_user(user_id) do
      Kjogvi.Cache.delete(key)
    end

    :ok
  end

  # Each call site of Log.recent_entries/2 uses a fixed (limit, cutoff_days)
  # tuple. Listing them here lets us evict by enumeration without having to
  # store a per-user version counter or scan the cache for matching keys.
  defp cache_keys_for_user(user_id) do
    today = Date.utc_today()

    for {limit, cutoff_days} <- known_variants() do
      build_key(user_id, limit, cutoff_days, today)
    end
  end

  # When adding a new call site of Log.recent_entries/2 with different
  # options, add the (limit, cutoff_days) tuple here so its cache entries
  # get invalidated alongside the others.
  defp known_variants do
    [
      # Home page (KjogviWeb.HomeController)
      {5, 93},
      # /my/log (KjogviWeb.My.Log.Index)
      {366, 366}
    ]
  end

  defp build_key(user_id, limit, cutoff_days, date) do
    @prefix <>
      "#{user_id}:#{limit}:#{cutoff_days}:#{Date.to_iso8601(date)}"
  end
end
