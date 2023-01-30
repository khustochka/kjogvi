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

  defmacro __using__(opts) do
    unless opts[:slug] do
      raise ArgumentError, "missing :slug option on use Ornitho.Importer.Generic"
    end

    unless opts[:version] do
      raise ArgumentError, "missing :version option on use Ornitho.Importer.Generic"
    end

    unless opts[:name] do
      raise ArgumentError, "missing :name option on use Ornitho.Importer.Generic"
    end

    quote bind_quoted: [opts: opts] do
      alias Ornitho.Schema.Book
      alias Ornitho.Schema.Taxon

      import Ecto.Query, only: [from: 2]

      @slug opts[:slug]
      @version opts[:version]
      @name opts[:name]

      def slug(), do: @slug
      def version(), do: @version
      def name(), do: @name

      def book_query() do
        from(Book, where: [slug: ^slug(), version: ^version()])
      end

      def taxa_query() do
        from(t in Taxon,
          where: t.book_id in subquery(from(book_query(), select: [:id]))
        )
      end
    end
  end
end
