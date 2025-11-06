defmodule Ornitho.Importer do
  @moduledoc """
  Generic importer. Usage example below. All three arguments are required.

  ## Examples

      use Ornitho.Importer,
        slug: "demo",
        version: "v1",
        name: "Demo book"
  """

  alias Ornitho.Schema.Book

  @callback create_taxa(config :: map(), book :: Book.t()) :: {:ok, integer()} | {:error, any()}
  @callback validate_config() :: {:ok, any()} | {:error, any()}

  @required_keys [:slug, :version, :name]
  @default_import_timeout 60_000

  defmacro __using__(opts) do
    missing_keys =
      for key <- @required_keys, reduce: [] do
        acc ->
          if opts[key] in [nil, ""] do
            [inspect(key) | acc]
          else
            acc
          end
      end

    if !Enum.empty?(missing_keys) do
      raise ArgumentError,
            "empty required option(s) #{Enum.join(missing_keys, ", ")} on " <>
              "`use Ornitho.Importer`"
    end

    quote bind_quoted: [opts: opts] do
      @behaviour Ornitho.Importer

      import Ecto.Query, only: [from: 2]

      alias Ornitho.Schema.Book
      alias Ornitho.Schema.Taxon
      alias Ornitho.Ops

      @slug opts[:slug]
      @version opts[:version]
      @name opts[:name]
      @description opts[:description]
      @publication_date opts[:publication_date]
      @extras opts[:extras]

      @spec slug() :: String.t()
      def slug(), do: @slug

      @spec version() :: String.t()
      def version(), do: @version

      @spec name() :: String.t()
      def name(), do: @name

      @spec description() :: nil | String.t()
      def description(), do: @description

      @spec publication_date() :: Date.t()
      def publication_date(), do: @publication_date

      @spec extras() :: nil | map()
      def extras(), do: @extras

      def process_import(opts \\ []) do
        force = opts[:force]

        with {:ok, config} <- validate_config() do
          Ops.transaction(
            fn ->
              with {:ok, _} <- prepare_repo(force: force),
                   {:ok, book} <- create_book(),
                   {:ok, taxa_count} = result <- create_taxa(config, book),
                   {:ok, _} <- finalize_imported_book(book, taxa_count) do
                result
              else
                {:error, e} -> Ops.rollback(e)
              end
            end,
            timeout: Ornitho.Importer.import_timeout()
          )
        end
      end

      defp prepare_repo(opts \\ []) do
        force = opts[:force]

        if Ornitho.Finder.Book.exists?(slug(), version()) do
          if force == true do
            Ops.Book.delete(slug(), version())
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
        %{
          slug: slug(),
          version: version(),
          name: name(),
          description: description(),
          publication_date: publication_date(),
          extras: extras(),
          importer: Atom.to_string(__MODULE__)
        }
      end

      defp create_book() do
        Ops.Book.create(book_attributes())
      end

      defp finalize_imported_book(book, taxa_count) do
        Ops.Book.finalize_imported_book(book, taxa_count)
      end
    end
  end

  def legit_importers() do
    Application.get_env(:ornithologue, __MODULE__)[:legit_importers] || []
  end

  def legit_importers_string() do
    legit_importers()
    |> Enum.map(&Atom.to_string/1)
  end

  def unimported() do
    imported =
      Ornitho.Finder.Book.all_importers()
      |> Enum.map(&String.to_existing_atom(&1))

    (legit_importers() -- imported)
    |> Enum.sort_by(& &1.publication_date(), {:desc, Date})
  end

  def import_timeout() do
    Application.get_env(:ornithologue, __MODULE__)[:import_timeout] || @default_import_timeout
  end
end
