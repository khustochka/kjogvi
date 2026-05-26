defmodule Ornitho.Query.Utils do
  @moduledoc """
  Query utilities.
  """

  import Ecto.Query

  def sanitize_like(str) do
    String.replace(str, ~r/(%|_|\\)/, "\\\\\\1")
  end

  @doc """
  Builds a dynamic `WHERE` fragment for composite-key `IN` filtering.

  Given a list of field names and a list of value tuples, emits SQL of the form
  `(field1, field2, ...) IN ((v1a, v2a, ...), (v1b, v2b, ...), ...)`. This is
  PostgreSQL's row constructor comparison — the multi-column equivalent of
  `WHERE col IN (?, ?)`, useful for fetching rows matching several composite
  keys in a single query.

  The fields are resolved against the first binding of the surrounding query.

  ## Example

      from(book in Book,
        where: ^Utils.tuple_in([:slug, :version], [{"clements", "v2024"}, {"ebird", "v2023"}])
      )

  produces

      WHERE (b0."slug", b0."version") IN (($1,$2), ($3,$4))
  """
  def tuple_in(fields, values) do
    field_count = length(fields)
    fields = Enum.map(fields, &quote(do: field(x, unquote(&1))))

    value_exprs =
      for v <- values, val <- Tuple.to_list(v) do
        quote do: ^unquote(val)
      end

    field_params = Enum.map_join(fields, ",", fn _ -> "?" end)
    one_tuple = "(" <> Enum.map_join(1..field_count, ",", fn _ -> "?" end) <> ")"
    value_params = Enum.map_join(values, ",", fn _ -> one_tuple end)
    pattern = "(#{field_params}) in (#{value_params})"

    quote do
      dynamic(
        [x],
        fragment(
          unquote(pattern),
          unquote_splicing(fields),
          unquote_splicing(value_exprs)
        )
      )
    end
    |> Code.eval_quoted()
    |> elem(0)
  end
end
