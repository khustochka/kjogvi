defmodule Kjogvi.Util.Presence do
  @moduledoc """
  Utility predicates for presence of values.

  A value is "blank" when it is `nil` or a string that is empty or only
  whitespace; everything else is "present".
  """

  # TODO: these values should never be empty strings in the first place —
  # blank text fields should be normalized to `nil` on write (e.g. in the
  # changeset). Once that holds, the empty-string handling here, and most
  # callers, can fall back to plain `nil` checks.

  @doc """
  ## Examples
    iex> Kjogvi.Util.Presence.present?(nil)
    false
    iex> Kjogvi.Util.Presence.present?("  ")
    false
    iex> Kjogvi.Util.Presence.present?("Anna")
    true
    iex> Kjogvi.Util.Presence.present?(0)
    true
  """
  def present?(nil), do: false
  def present?(value) when is_binary(value), do: String.trim(value) != ""
  def present?(_), do: true

  def presence(nil), do: nil

  def presence(value) when is_binary(value) do
    if present?(value), do: String.trim(value), else: nil
  end

  def presence(value), do: value

  @doc """
  ## Examples
    iex> Kjogvi.Util.Presence.blank?(nil)
    true
    iex> Kjogvi.Util.Presence.blank?("Anna")
    false
  """
  def blank?(value), do: not present?(value)
end
