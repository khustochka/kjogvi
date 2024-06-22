defmodule Kjogvi.Util.SQLFormatter do
  @moduledoc """
  SQL Formatter utility. Adopted from:
  https://github.com/mrdziuban/sql-formatter/blob/master/elixirscript/src/SQLFormatter.exjs
  """

  defmodule T do
    @moduledoc false

    defstruct str: nil,
              shift_arr: [],
              tab: nil,
              arr: [],
              parens_level: 0,
              deep: 0
  end

  @sep "~::~"

  def format(sql, num_spaces \\ 2) do
    tab = String.duplicate(" ", num_spaces)

    split_by_quotes =
      sql
      |> (&Regex.replace(~r/\s+/, &1, " ")).()
      |> (&Regex.replace(~r/'/, &1, "#{@sep}'")).()
      |> String.split(@sep)

    input = %T{
      str: "",
      shift_arr: create_shift_arr(tab),
      tab: tab,
      arr:
        split_by_quotes
        |> length
        |> (fn l -> upto(l - 1) end).()
        |> Enum.map(fn i -> split_if_even(i, Enum.at(split_by_quotes, i), tab) end)
        |> Enum.reduce([], fn x, acc -> Enum.concat(acc, x) end)
    }

    input
    |> gen_output(0, length(input.arr))
    |> Map.get(:str)
    |> (&Regex.replace(~r/\s+\n/, &1, "\n")).()
    |> (&Regex.replace(~r/\n+/, &1, "\n")).()
    |> String.trim()
  end

  defp gen_output(acc, i, max) when i < max do
    original_el = Enum.at(acc.arr, i)
    parens_level = subquery_level(original_el, acc.parens_level)

    arr =
      case Regex.match?(~r/SELECT|SET/, original_el) do
        true ->
          List.replace_at(
            acc.arr,
            i,
            Regex.replace(~r/,\s+/, original_el, ",\n#{acc.tab}#{acc.tab}")
          )

        false ->
          acc.arr
      end

    el = Enum.at(arr, i)

    {str, deep} =
      case Regex.match?(~r/\(\s*SELECT/, el) do
        true ->
          {"#{acc.str}#{Enum.at(acc.shift_arr, acc.deep + 1)}#{el}", acc.deep + 1}

        false ->
          {if(Regex.match?(~r/'/, el),
             do: "#{acc.str}#{el}",
             else: "#{acc.str}#{Enum.at(acc.shift_arr, acc.deep)}#{el}"
           ), if(parens_level < 1 && acc.deep != 0, do: acc.deep - 1, else: acc.deep)}
      end

    gen_output(%{acc | str: str, arr: arr, parens_level: parens_level, deep: deep}, i + 1, max)
  end

  defp gen_output(acc, _, _), do: acc

  defp upto(i), do: upto([], i)
  defp upto(arr, i) when i < 0, do: arr
  defp upto(arr, i), do: upto([i | arr], i - 1)

  defp create_shift_arr(tab), do: Enum.map(upto(99), &"\n#{String.duplicate(tab, &1)}")

  defp subquery_level(str, level) do
    level -
      (String.length(Regex.replace(~r/\(/, str, "")) -
         String.length(Regex.replace(~r/\)/, str, "")))
  end

  defp all_replacements(tab) do
    [
      {~r/ AND /i, @sep <> tab <> "AND "},
      {~r/ BETWEEN /i, @sep <> tab <> "BETWEEN "},
      {~r/ CASE /i, @sep <> tab <> "CASE "},
      {~r/ ELSE /i, @sep <> tab <> "ELSE "},
      {~r/ END /i, @sep <> tab <> "END "},
      {~r/ FROM /i, @sep <> "FROM "},
      {~r/ GROUP\s+BY /i, @sep <> "GROUP BY "},
      {~r/ HAVING /i, @sep <> "HAVING "},
      {~r/ IN /i, " IN "},
      {~r/ JOIN /i, @sep <> "JOIN "},
      {~r/ CROSS(~::~)+JOIN /i, @sep <> "CROSS JOIN "},
      {~r/ INNER(~::~)+JOIN /i, @sep <> "INNER JOIN "},
      {~r/ LEFT(~::~)+JOIN /i, @sep <> "LEFT JOIN "},
      {~r/ RIGHT(~::~)+JOIN /i, @sep <> "RIGHT JOIN "},
      {~r/ ON /i, @sep <> tab <> "ON "},
      {~r/ OR /i, @sep <> tab <> "OR "},
      {~r/ ORDER\s+BY /i, @sep <> "ORDER BY "},
      {~r/ OVER /i, @sep <> tab <> "OVER "},
      {~r/\(\s*SELECT /i, @sep <> "(SELECT "},
      {~r/\)\s*SELECT /i, ")" <> @sep <> "SELECT "},
      {~r/ THEN /i, " THEN" <> @sep <> tab},
      {~r/ UNION /i, @sep <> "UNION" <> @sep},
      {~r/ USING /i, @sep <> "USING "},
      {~r/ WHEN /i, @sep <> tab <> "WHEN "},
      {~r/ WHERE /i, @sep <> "WHERE "},
      {~r/ WITH /i, @sep <> "WITH "},
      {~r/ SET /i, @sep <> "SET "},
      {~r/ ALL /i, " ALL "},
      {~r/ AS /i, " AS "},
      {~r/ ASC /i, " ASC "},
      {~r/ DESC /i, " DESC "},
      {~r/ DISTINCT /i, " DISTINCT "},
      {~r/ EXISTS /i, " EXISTS "},
      {~r/ NOT /i, " NOT "},
      {~r/ NULL /i, " NULL "},
      {~r/ LIKE /i, " LIKE "},
      {~r/\s*SELECT /i, "SELECT "},
      {~r/\s*UPDATE /i, "UPDATE "},
      {~r/\s*DELETE /i, "DELETE "},
      {~r/(~::~)+/, @sep}
    ]
  end

  defp do_replace([], str), do: str
  defp do_replace([h], str), do: Regex.replace(elem(h, 0), str, elem(h, 1))
  defp do_replace([h | t], str), do: do_replace(t, Regex.replace(elem(h, 0), str, elem(h, 1)))

  defp split_sql(str, tab) do
    tab
    |> all_replacements
    |> do_replace(Regex.replace(~r/\s+/, str, " "))
    |> String.split(@sep)
  end

  defp split_if_even(i, str, tab) when rem(i, 2) == 0, do: split_sql(str, tab)
  defp split_if_even(_, str, _), do: [str]
end
