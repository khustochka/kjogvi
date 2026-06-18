defmodule Ornitho.Util do
  @moduledoc """
  Helpers for casting raw CSV cell values into taxon attributes.

  Import source files store every cell as a string, and missing values arrive as
  empty strings rather than `nil`. These functions normalize that: an empty (or
  whitespace-only) string becomes `nil` for every type.
  """

  @doc """
  Returns the trimmed string, or `nil` for a blank or missing value.
  """
  @spec cast_string(String.t() | nil) :: String.t() | nil
  def cast_string(value) do
    case normalize(value) do
      nil -> nil
      str -> str
    end
  end

  @doc """
  Parses an integer, or returns `nil` for a blank or missing value.

  Raises `ArgumentError` on a non-blank value that is not a valid integer.
  """
  @spec cast_integer(String.t() | nil) :: integer() | nil
  def cast_integer(value) do
    case normalize(value) do
      nil -> nil
      str -> String.to_integer(str)
    end
  end

  @doc """
  Parses `"true"`/`"false"` into a boolean, or returns `nil` for a blank or missing
  value.

  Raises `ArgumentError` on any other non-blank value.
  """
  @spec cast_boolean(String.t() | nil) :: boolean() | nil
  def cast_boolean(value) do
    case normalize(value) do
      nil -> nil
      "true" -> true
      "false" -> false
      other -> raise ArgumentError, "expected a boolean string, got: #{inspect(other)}"
    end
  end

  defp normalize(nil), do: nil

  defp normalize(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
