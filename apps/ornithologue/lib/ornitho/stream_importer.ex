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

      @impl Ornitho.Importer
      def create_taxa(config, book) do
        case file_streamer(config, file_path()) do
          {:error, _} = err -> err
          stream -> create_taxa_from_stream(book, stream)
        end
      end

      defp create_taxa_from_stream(book, stream) do
        with {:ok, {n, relations_cache}} <- insert_taxa(book, stream),
             {:ok, _} <- set_parent_species(book, relations_cache) do
          {:ok, n}
        end
      end

      defp insert_taxa(book, stream) do
        stream
        |> CSV.decode(headers: true)
        |> Stream.chunk_every(chunk_size())
        |> Enum.reduce({0, %{}}, fn chunk, {num_saved, relations_cache} ->
          time = DateTime.utc_now()
          taxa_to_insert = Enum.map(chunk, fn {:ok, row} -> to_taxon_attrs(book, row, time) end)

          {num_inserted, inserted} = Ops.insert_all(Taxon, taxa_to_insert)

          new_children =
            chunk
            |> Enum.filter(fn {:ok, row} -> row["parent_species_code"] end)
            |> Enum.group_by(
              fn {:ok, row} -> row["parent_species_code"] end,
              fn {:ok, row} -> row["code"] end
            )

          # Cache matching species code to array of its children codes
          new_relations_cache =
            Map.merge(relations_cache, new_children, fn _sp_code, old, new -> old ++ new end)

          {num_saved + num_inserted, new_relations_cache}
        end)
        |> case do
          result -> {:ok, result}
        end
      end

      defp set_parent_species(book, relations_cache) do
        Enum.each(relations_cache, fn {sp_code, child_codes} ->
          Ops.Taxon.set_parent_species(book.id, sp_code, child_codes)
        end)

        {:ok, map_size(relations_cache)}
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

      defp str_to_bool(val) do
        case val do
          "true" -> true
          "false" -> false
          "" -> nil
          nil -> nil
        end
      end

      defp chunk_size, do: 2_000
    end
  end
end
