defmodule Kjogvi.Settings.Setting.Value do
  @moduledoc """
  Pass-through Ecto type for the `jsonb` settings value: stores any
  JSON-representable term (boolean, string, number, list, map) as-is, without
  forcing it into a map the way the built-in `:map` type would.
  """

  use Ecto.Type

  def type, do: :map

  def cast(value), do: {:ok, value}

  def load(value), do: {:ok, value}

  def dump(value), do: {:ok, value}
end
