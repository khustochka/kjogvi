defmodule Kjogvi.Util.Token do
  @moduledoc """
  Opaque, URL-safe random tokens for use in public identifiers and storage
  paths (e.g. a user's or image's public token).
  """

  # Lowercase Crockford-ish base32 without padding: unambiguous, URL-safe, and
  # case-insensitive-friendly.
  @alphabet ~c"0123456789abcdefghjkmnpqrstvwxyz"
  @default_length 12

  @doc """
  Generates a random token of `length` characters (default #{@default_length}).
  """
  def generate(length \\ @default_length) when is_integer(length) and length > 0 do
    for _ <- 1..length, into: "", do: <<Enum.random(@alphabet)>>
  end
end
