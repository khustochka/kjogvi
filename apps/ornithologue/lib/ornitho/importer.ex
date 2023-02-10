defmodule Ornitho.Importer do
  @moduledoc """
  Generic importer. Usage example below. All three arguments are required.

  ## Examples

      use Ornitho.Importer,
        slug: "demo",
        version: "v1",
        name: "Demo book"
  """

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

      @callback create_taxa(book :: %Book{}) :: {:ok, any()} | {:error, any()}

      import Ecto.Query, only: [from: 2]

      @slug opts[:slug]
      @version opts[:version]
      @name opts[:name]
      @description opts[:description]
      @extras opts[:extras]

      @spec slug() :: String.t()
      def slug(), do: @slug

      @spec version() :: String.t()
      def version(), do: @version

      @spec name() :: String.t()
      def name(), do: @name

      @spec description() :: nil | String.t()
      def description(), do: @description

      @spec extras() :: nil | map()
      def extras(), do: @extras

      def process_import(opts \\ []) do
        force = opts[:force]

        with {:ok, _} <- prepare_repo(force: force),
             {:ok, book} <- create_book(),
             {:ok, _} = result <- create_taxa(book),
             {1, _} <- update_imported_time(book)
             do
          result
        else
          {:error, e} when is_binary(e) -> raise(e)
          {:error, e} -> raise(inspect(e))
        end
      end

      defp prepare_repo(opts \\ []) do
        force = opts[:force]

        if Ornitho.Find.Book.exists?(slug(), version()) do
          if force == true do
            Ornitho.delete_book(slug(), version())
            {:ok, :ready}
          else
            raise(
              "A book for importer #{inspect(__MODULE__)} already exists, " <>
                "to force overwrite it pass [force: true] (or --force in a Mix task. " <>
                "Please note that in this case all taxa will be deleted!"
            )
          end
        else
          {:ok, :ready}
        end
      end

      def book_attributes() do
        %Book{
          slug: slug(),
          version: version(),
          name: name(),
          description: description(),
          extras: extras()
        }
      end

      defp create_book() do
        Ornitho.create_book(book_attributes())
      end

      defp update_imported_time(book) do
        Ornitho.mark_book_imported(book)
      end
    end
  end
end
