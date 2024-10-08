defmodule Kjogvi.Legacy.Import do
  @moduledoc false

  def run(user) do
    :telemetry.span([:kjogvi, :legacy, :import], telemetry_metadata(), fn ->
      prepare_import()
      perform_import(:locations)
      perform_import(:cards, user: user)
      perform_import(:observations)

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

  defp load(object_type, fetcher, page, opts) do
    results = adapter().fetch_page(object_type, fetcher, page)

    if Enum.empty?(results.rows) do
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
