defmodule Kjogvi.Util.Enum do
  @moduledoc """
  Utility Enum functions.
  """

  @doc """
  Zips a list with a boolean representing inclusion of each element in a sublist. Lists order
  should match.

  ## Examples
    iex> list = Enum.to_list(2005..2009)
    iex> Kjogvi.Util.Enum.zip_inclusion(list, [2006, 2008, 2009])
    [{2005, false}, {2006, true}, {2007, false}, {2008, true}, {2009, true}]
  """
  def zip_inclusion(list, sublist) do
    {res, _} =
      Enum.reduce(list, {[], sublist}, fn el, {acc, subl} ->
        case subl do
          [^el | rest] -> {[{el, true} | acc], rest}
          _ -> {[{el, false} | acc], subl}
        end
      end)

    Enum.reverse(res)
  end
end
