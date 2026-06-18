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

  @callback create_taxa(config :: map(), book :: Book.t(), source :: any()) ::
              {:ok, integer()} | {:error, any()}
  @callback validate_config() :: {:ok, any()} | {:error, any()}

  @doc """
  Runs before the import transaction opens, so slow setup (e.g. downloading a source
  file) does not run with a database connection checked out or eat into the transaction
  timeout. The `{:ok, source}` it returns is threaded into `create_taxa/3`. Defaults to
  `{:ok, nil}`. Importers that need pre-transaction work (see `Ornitho.StreamImporter`)
  override this; returning `{:error, reason}` aborts the import before any database work.
  """
  @callback before_transaction(config :: map()) :: {:ok, any()} | {:error, any()}

  @optional_callbacks before_transaction: 1

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
          :telemetry.span([:ornitho, :import], %{importer: __MODULE__}, fn ->
            # Run pre-transaction setup (e.g. downloading the source file) outside the
            # transaction so it does not hold a database connection or eat into the
            # transaction timeout.
            result =
              with {:ok, source} <- before_transaction(config) do
                run_import(config, source, force)
              end

            taxa_count =
              case result do
                {:ok, count} -> count
                _ -> nil
              end

            {result, %{importer: __MODULE__, taxa_count: taxa_count}}
          end)
        end
      end

      @impl Ornitho.Importer
      def before_transaction(_config), do: {:ok, nil}

      defoverridable before_transaction: 1

      defp run_import(config, source, force) do
        Ops.transact(
          fn ->
            with {:ok, _} <- prepare_repo(force: force),
                 {:ok, book} <- create_book(),
                 {:ok, taxa_count} = result <- create_taxa(config, book, source),
                 {:ok, _} <- finalize_imported_book(book, taxa_count) do
              result
            end
          end,
          timeout: Ornitho.Importer.import_timeout()
        )
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
