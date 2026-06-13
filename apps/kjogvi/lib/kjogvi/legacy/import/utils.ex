defmodule Kjogvi.Legacy.Import.Utils do
  @moduledoc false

  @doc """
  Converts a legacy timestamp value into a UTC `DateTime`.

  Accepts a `NaiveDateTime` (assumed UTC), an ISO 8601 string, or `nil`
  (returns `nil`). Callers needing a fallback for `nil` can use `||`.
  """
  def convert_timestamp(nil), do: nil

  def convert_timestamp(%NaiveDateTime{} = time) do
    {:ok, converted} = DateTime.from_naive(time, "Etc/UTC")
    converted
  end

  def convert_timestamp(time) when is_binary(time) do
    {:ok, dt, _} = DateTime.from_iso8601(time)
    {usec, _} = dt.microsecond
    %{dt | microsecond: {usec, 6}}
  end

  @doc """
  Normalizes a legacy text value: trims it and turns blank/whitespace-only
  strings into `nil`. Non-binary values pass through unchanged.
  """
  def blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  def blank_to_nil(value), do: value
end
