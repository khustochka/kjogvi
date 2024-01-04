defmodule Kjogvi.Query.API do
  @moduledoc """
  Macros to be used in Ecto queries.
  """

  defmacro extract(segment, field) do
    quote do
      fragment("extract(? from ?)", unquote(segment), unquote(field))
    end
  end

  defmacro extract_year(field) do
    quote do
      type(extract("year", unquote(field)), :integer)
    end
  end

  defmacro extract_month(field) do
    quote do
      type(extract("month", unquote(field)), :integer)
    end
  end
end
