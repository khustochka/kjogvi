defmodule Ornitho.Query.Utils do
  @moduledoc """
  Query utilities.
  """

  import Ecto.Query

  def sanitize_like(str) do
    String.replace(str, ~r/(%|_|\\)/, "\\\\\\1")
  end

  def tuple_in(fields, values) do
    fields = Enum.map(fields, &quote(do: field(x, unquote(&1))))
    values = for v <- values, do: quote(do: fragment("(?)", splice(^unquote(Tuple.to_list(v)))))
    field_params = Enum.map_join(fields, ",", fn _ -> "?" end)
    value_params = Enum.map_join(values, ",", fn _ -> "?" end)
    pattern = "(#{field_params}) in (#{value_params})"

    quote do
      dynamic(
        [x],
        fragment(unquote(pattern), unquote_splicing(fields), unquote_splicing(values))
      )
    end
    |> Code.eval_quoted()
    |> elem(0)
  end
end
