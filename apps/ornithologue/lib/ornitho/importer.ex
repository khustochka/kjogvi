defmodule Ornitho.Importer do
  @moduledoc """
  Generic importer. Usage example below. All three arguments are required.

  ## Examples

      use Ornitho.Importer,
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
              "`use Ornitho.Importer`"
    end

    quote bind_quoted: [opts: opts] do
      alias Ornitho.Schema.{Book, Taxon}

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

      def process_import(opts \\ []) do
        force = opts[:force]

        with {:ok, _} <- prepare_repo(force: force),
             {:ok, book} <- create_book() do
          create_taxa(book)
        else
          e = {:error, _} -> e
        end
      end

      defp prepare_repo(opts \\ []) do
        force = opts[:force]

        if book_exists?() do
          if force == true do
            delete_book()
            {:ok, :ready}
          else
            raise(
              "A book for importer #{inspect(__MODULE__)} already exists, " <>
                "to force overwrite it pass [force: true] (or --force in a Mix task. " <>
                "Please note that in this case all taxa will be deleted!")
          end
        else
          {:ok, :ready}
        end
      end

      defp book_exists?() do
        book_query()
        |> Ornitho.Repo.exists?()
      end

      defp delete_book() do
        book_query()
        |> Ornitho.Repo.delete_all()
      end

      def book_query() do
        from(Book, where: [slug: ^slug(), version: ^version()])
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

      defp create_book() do
        Ornitho.create_book(book_map())
      end

      defp create_taxa(book) do
        # importer.create_taxa(book)
        {:ok, :done}
      end
    end
  end
end
