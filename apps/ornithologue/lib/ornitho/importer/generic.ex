defmodule Ornitho.Importer.Generic do
  @moduledoc """
  Generic importer. Usage example below. All three arguments are required.

  ## Examples

      use Ornitho.Importer.Generic,
        slug: "demo",
        version: "v1",
        name: "Demo book"
  """

  # TODO: add behaviours.
  @required_keys [:slug, :version, :name]

  defmacro __using__(opts) do
    {keys, _} = opts |> Keyword.split(@required_keys)

    keys =
      keys
      |> Enum.filter(fn {_, v} -> not is_nil(v) end)
      |> Keyword.keys()
      |> Enum.uniq()

    missing_keys =
      (@required_keys -- keys)
      |> Enum.map(&Atom.to_string/1)
      |> Enum.map(fn str -> ":#{str}" end)

    unless Enum.empty?(missing_keys) do
      raise ArgumentError,
            "missing required option(s) #{missing_keys |> Enum.join(", ")} on " <>
              "`use Ornitho.Importer.Generic`"
    end

    quote bind_quoted: [opts: opts] do
      alias Ornitho.Schema.Book
      alias Ornitho.Schema.Taxon

      import Ecto.Query, only: [from: 2]

      @slug opts[:slug]
      @version opts[:version]
      @name opts[:name]
      @description opts[:description]
      @extras opts[:extras]

      def slug(), do: @slug
      def version(), do: @version
      def name(), do: @name
      def description(), do: @description
      def extras(), do: @extras

      def book_query() do
        from(Book, where: [slug: ^slug(), version: ^version()])
      end

      def taxa_query() do
        from(t in Taxon,
          where: t.book_id in subquery(from(book_query(), select: [:id]))
        )
      end

      def book_map do
        %Book{
          slug: slug(),
          version: version(),
          name: name(),
          description: description(),
          extras: extras()
        }
      end
    end
  end
end
