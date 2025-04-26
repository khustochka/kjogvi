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

  @callback create_taxa_from_stream(book :: Book.t(), stream :: Enumerable.t()) ::
              {:ok, integer()} | {:error, any()}

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
    end
  end
end
