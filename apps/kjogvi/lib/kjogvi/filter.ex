defmodule Kjogvi.Filter do
  @moduledoc """
  Shared scaffolding for `NimbleOptions`-backed filter structs (e.g. the
  checklists-index and lifelist filters).

  `use Kjogvi.Filter, schema: schema` defines, for the calling module:

    * a `defstruct` whose fields are the schema keys, each defaulting to its
      schema `:default` — so a bare `%Filter{}` is already a valid, blank
      filter without going through `discombo!/1`.
    * `discombo/1` — validates a keyword/map of options against the schema,
      returning `{:ok, filter}` or `NimbleOptions`' `{:error, error}`.
    * `discombo!/1` — same, raising on invalid input and returning the filter.

  Both builders accept either a keyword list or a map. Domain-specific helpers
  (predicates, param encoding, …) stay in the using module.
  """

  defmacro __using__(opts) do
    schema = Keyword.fetch!(opts, :schema)

    quote do
      @filter_schema unquote(schema)

      defstruct Enum.map(@filter_schema, fn {key, field_opts} ->
                  {key, Keyword.get(field_opts, :default)}
                end)

      @doc """
      Builds a filter from a keyword list / map of options, validating types.
      Raises on invalid input.
      """
      def discombo!(opts) do
        opts
        |> Enum.into([])
        |> NimbleOptions.validate!(@filter_schema)
        |> then(&struct!(__MODULE__, &1))
      end

      @doc """
      Builds a filter, returning `{:ok, filter}` or `{:error, error}`.
      """
      def discombo(opts) do
        case opts |> Enum.into([]) |> NimbleOptions.validate(@filter_schema) do
          {:ok, result} -> {:ok, struct!(__MODULE__, result)}
          err -> err
        end
      end
    end
  end
end
