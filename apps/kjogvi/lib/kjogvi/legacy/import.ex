defmodule Kjogvi.Legacy.Import do
  @moduledoc false

  def run(user, opts \\ []) do
    :telemetry.span([:kjogvi, :legacy, :import], telemetry_metadata(), fn ->
      new_opts = opts ++ [user: user]

      prepare_import(new_opts)

      perform_import(:locations, new_opts)

      perform_import(:cards, new_opts)

      perform_import(:observations, new_opts)

      broadcast_progress(opts[:import_id], "Legacy import done.")

      {:ok, telemetry_metadata()}
    end)
  end

  def prepare_import(opts \\ []) do
    broadcast_progress(opts[:import_id], "Preparing legacy import...")

    :telemetry.span([:kjogvi, :legacy, :import, :prepare], telemetry_metadata(), fn ->
      Kjogvi.Legacy.Import.Observations.truncate()
      Kjogvi.Legacy.Import.Cards.truncate()
      Kjogvi.Legacy.Import.Locations.truncate()

      {:ok, telemetry_metadata()}
    end)
  end

  def perform_import(object_type, opts \\ []) do
    broadcast_progress(opts[:import_id], "Importing #{Atom.to_string(object_type)}...")

    :telemetry.span([:kjogvi, :legacy, :import, object_type], telemetry_metadata(), fn ->
      result = load(object_type, adapter().init(), {1, 0}, opts)

      {result, telemetry_metadata()}
    end)
  end

  def subscribe_progress(import_id) do
    Phoenix.PubSub.subscribe(Kjogvi.PubSub, progress_key(import_id))
  end

  defp broadcast_progress(nil, _message) do
    :ok
  end

  defp broadcast_progress(import_id, message) do
    Phoenix.PubSub.broadcast(
      Kjogvi.PubSub,
      progress_key(import_id),
      {:legacy_import_progress, %{message: message}}
    )
  end

  defp progress_key(import_id) do
    "legacy_import:progress:#{import_id}"
  end

  defp load(object_type, fetcher, {page, loaded}, opts) do
    results = adapter().fetch_page(object_type, fetcher, page)

    if Enum.empty?(results.rows) do
      after_import(object_type, opts)
      :ok
    else
      put_loaded(object_type, results.columns, results.rows, opts)
      count = loaded + length(results.rows)
      broadcast_progress(opts[:import_id], "Importing #{Atom.to_string(object_type)}... #{count}")
      load(object_type, fetcher, {page + 1, count}, opts)
    end
  end

  defp put_loaded(:locations, columns, rows, opts) do
    Kjogvi.Legacy.Import.Locations.import(columns, rows, opts)
  end

  defp put_loaded(:cards, columns, rows, opts) do
    Kjogvi.Legacy.Import.Cards.import(columns, rows, opts)
  end

  defp put_loaded(:observations, columns, rows, opts) do
    Kjogvi.Legacy.Import.Observations.import(columns, rows, opts)
  end

  defp after_import(:locations, opts) do
    broadcast_progress(opts[:import_id], "Caching public locations...")
    Kjogvi.Legacy.Import.Locations.after_import()
  end

  defp after_import(:cards, _opts) do
    # Kjogvi.Legacy.Import.Cards.after_import()
  end

  defp after_import(:observations, opts) do
    broadcast_progress(opts[:import_id], "Caching observation species...")
    Kjogvi.Legacy.Import.Observations.after_import()
  end

  def config do
    Application.get_env(:kjogvi, :legacy)
  end

  defp adapter do
    config()[:adapter]
  end

  defp telemetry_metadata() do
    %{adapter: adapter()}
  end
end
