defmodule Kjogvi.Util.Number do
  @moduledoc """
  Utility functions for formatting numbers.
  """

  @doc """
  Groups an integer's digits in threes with commas.

  ## Examples
      iex> Kjogvi.Util.Number.delimit(42)
      "42"
      iex> Kjogvi.Util.Number.delimit(12345)
      "12,345"
      iex> Kjogvi.Util.Number.delimit(1234567)
      "1,234,567"
  """
  def delimit(number) do
    number
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end
end
