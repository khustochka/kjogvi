defmodule Kjogvi.Util.Time do
  @moduledoc """
  Utility functions for presenting times.
  """

  @minute 60
  @hour 3600
  @day 86_400

  @doc """
  A coarse, English, timezone-free "ago" phrase for a past `DateTime`.

  Rounds to the largest whole unit; anything under a minute reads "just now".
  A future time (clock skew) also reads "just now".

  ## Examples
      iex> now = ~U[2026-08-21 14:05:00Z]
      iex> Kjogvi.Util.Time.relative(~U[2026-08-21 14:04:30Z], now)
      "just now"
      iex> Kjogvi.Util.Time.relative(~U[2026-08-21 14:03:00Z], now)
      "2 minutes ago"
      iex> Kjogvi.Util.Time.relative(~U[2026-08-21 13:05:00Z], now)
      "1 hour ago"
      iex> Kjogvi.Util.Time.relative(~U[2026-08-18 14:05:00Z], now)
      "3 days ago"
  """
  def relative(at, now \\ DateTime.utc_now()) do
    case DateTime.diff(now, at, :second) do
      diff when diff < @minute -> "just now"
      diff when diff < @hour -> ago(div(diff, @minute), "minute")
      diff when diff < @day -> ago(div(diff, @hour), "hour")
      diff -> ago(div(diff, @day), "day")
    end
  end

  defp ago(1, unit), do: "1 #{unit} ago"
  defp ago(n, unit), do: "#{n} #{unit}s ago"
end
