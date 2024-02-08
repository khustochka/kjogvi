defmodule Kjogvi.Legacy.Import do
  @moduledoc false

  def run(opts \\ []) do
    prepare_import(opts)
    perform_import(:locations, opts)
    perform_import(:cards, opts)
    perform_import(:observations, opts)
  end

  def prepare_import(_opts \\ []) do
    Kjogvi.Legacy.Import.Observations.truncate()
    Kjogvi.Legacy.Import.Cards.truncate()
    Kjogvi.Legacy.Import.Locations.truncate()

    :ok
  end

  def perform_import(object_type, opts \\ []) do
    load(object_type, adapter().init, 1)

    if pid = opts[:pid] do
      send(pid, {:legacy_import, {:done, object_type}})
    end

    :ok
  end

  defp load(object_type, fetcher, page) do
    results = adapter().fetch_page(object_type, fetcher, page)

    if Enum.empty?(results.rows) do
      :ok
    else
      put_loaded(object_type, results.columns, results.rows)
      load(object_type, fetcher, page + 1)
    end
  end

  defp put_loaded(:locations, columns, rows) do
    Kjogvi.Legacy.Import.Locations.import(columns, rows)
  end

  defp put_loaded(:cards, columns, rows) do
    Kjogvi.Legacy.Import.Cards.import(columns, rows)
  end

  defp put_loaded(:observations, columns, rows) do
    Kjogvi.Legacy.Import.Observations.import(columns, rows)
  end

  def config do
    Application.get_env(:kjogvi, :legacy)
  end

  defp adapter do
    config()[:adapter]
  end
end
