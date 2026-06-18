defmodule Ornitho.StreamImporter do
  @moduledoc """
  Imports species from CSV stream (local or downloaded file). Usage example below.

  ## Examples

      use Ornitho.StreamImporter,
        slug: "demo",
        version: "v1",
        name: "Demo book",
        file_path: /import/demo/v1/ornithologue_demo_v1.csv
  """

  alias Ornitho.Schema.Book
  alias Ornitho.Ops
  alias Ornitho.Schema.Taxon

  @callback to_taxon_attrs(book :: Book.t(), row :: map(), time :: DateTime) :: map()

  @required_keys [:file_path]

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
      @behaviour Ornitho.StreamImporter

      @file_path opts[:file_path]

      @spec slug() :: String.t()
      def file_path(), do: @file_path

      # The source file is fetched here, before the transaction opens, so a slow S3
      # download does not hold a database connection or eat into the transaction
      # timeout. The stream is threaded into `create_taxa/3`.
      @impl Ornitho.Importer
      def before_transaction(config) do
        case file_streamer(config, file_path()) do
          {:error, _} = err -> err
          stream -> {:ok, stream}
        end
      end

      @impl Ornitho.Importer
      def create_taxa(_config, book, stream) do
        create_taxa_from_stream(book, stream)
      end

      defp create_taxa_from_stream(book, stream) do
        num_saved = insert_taxa(book, stream)
        Ops.Taxon.link_parent_species(book.id)
        {:ok, num_saved}
      end

      # Inserts taxa in chunks. The child's `parent_species_code` is stashed in `extras`
      # so the parent link can be resolved afterwards in a single self-join (the parent
      # may live in the same or an earlier chunk, so its id is not known at insert time).
      defp insert_taxa(book, stream) do
        stream
        |> CSV.decode(headers: true)
        |> Stream.chunk_every(chunk_size())
        |> Enum.reduce(0, fn chunk, num_saved ->
          time = DateTime.utc_now()

          taxa_to_insert =
            Enum.map(chunk, fn {:ok, row} ->
              book
              |> to_taxon_attrs(row, time)
              |> put_parent_species_code(row["parent_species_code"])
            end)

          {num_inserted, _} = Ops.insert_all(Taxon, taxa_to_insert)

          num_saved + num_inserted
        end)
      end

      defp put_parent_species_code(attrs, nil), do: attrs
      defp put_parent_species_code(attrs, ""), do: attrs

      defp put_parent_species_code(attrs, code) do
        extras = Map.put(attrs[:extras] || %{}, "parent_species_code", code)
        Map.put(attrs, :extras, extras)
      end

      defp file_streamer(config, path) do
        adapter().file_streamer(config, path)
      end

      @impl Ornitho.Importer
      def validate_config do
        adapter().validate_config()
      end

      defp config() do
        Application.get_env(:ornithologue, Ornitho.StreamImporter)
      end

      defp adapter() do
        config()[:adapter]
      end

      defp chunk_size, do: 2_000
    end
  end
end
