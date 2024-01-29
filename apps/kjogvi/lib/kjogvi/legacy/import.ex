defmodule Kjogvi.Legacy.Import do
  @moduledoc false

  def run do
    prepare_import()
    perform_import(:locations)
    perform_import(:cards)
    perform_import(:observations)
  end

  def prepare_import do
    Kjogvi.Legacy.Import.Observations.truncate()
    Kjogvi.Legacy.Import.Cards.truncate()
    Kjogvi.Legacy.Import.Locations.truncate()

    :ok
  end

  def perform_import(object_type) do
    load(object_type, adapter().init, 1)
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
