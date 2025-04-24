defmodule Kjogvi.Legacy.Import do
  @moduledoc false

  def run(user, opts \\ []) do
    :telemetry.span([:kjogvi, :legacy, :import], telemetry_metadata(), fn ->
      import_id = opts[:import_id]

      with_progress_subscription(import_id, "Preparing legacy import...", fn ->
        prepare_import()
      end)

      with_progress_subscription(import_id, "Importing locations...", fn ->
        perform_import(:locations)
      end)

      with_progress_subscription(import_id, "Importing cards...", fn ->
        perform_import(:cards, user: user)
      end)

      with_progress_subscription(import_id, "Importing observations...", fn ->
        perform_import(:observations)
      end)

      with_progress_subscription(import_id, "Legacy import done.")

      {:ok, telemetry_metadata()}
    end)
  end

  def prepare_import do
    :telemetry.span([:kjogvi, :legacy, :import, :prepare], telemetry_metadata(), fn ->
      Kjogvi.Legacy.Import.Observations.truncate()
      Kjogvi.Legacy.Import.Cards.truncate()
      Kjogvi.Legacy.Import.Locations.truncate()

      {:ok, telemetry_metadata()}
    end)
  end

  def perform_import(object_type, opts \\ []) do
    :telemetry.span([:kjogvi, :legacy, :import, object_type], telemetry_metadata(), fn ->
      result = load(object_type, adapter().init(), 1, opts)

      {result, telemetry_metadata()}
    end)
  end

  def subscribe_progress(import_id) do
    Phoenix.PubSub.subscribe(Kjogvi.PubSub, progress_key(import_id))
  end

  defp with_progress_subscription(import_id, message, func \\ nil) do
    broadcast_progress(import_id, message)

    if func do
      func.()
    end
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

  defp load(object_type, fetcher, page, opts) do
    results = adapter().fetch_page(object_type, fetcher, page)

    if Enum.empty?(results.rows) do
      after_import(object_type)
      :ok
    else
      put_loaded(object_type, results.columns, results.rows, opts)
      load(object_type, fetcher, page + 1, opts)
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

  defp after_import(:locations) do
    Kjogvi.Legacy.Import.Locations.after_import()
  end

  defp after_import(:cards) do
    # Kjogvi.Legacy.Import.Cards.after_import()
  end

  defp after_import(:observations) do
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
