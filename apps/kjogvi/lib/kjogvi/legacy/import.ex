defmodule Kjogvi.Legacy.Import do
  @moduledoc false

  def run(user, opts \\ []) do
    new_opts = Keyword.put(opts, :user, user)

    :telemetry.span([:kjogvi, :legacy, :import], telemetry_metadata(new_opts), fn ->
      prepare_import(new_opts)

      perform_import(:locations, new_opts)

      perform_import(:cards, new_opts)

      perform_import(:observations, new_opts)

      {:ok, telemetry_metadata(new_opts)}
    end)
  end

  def prepare_import(opts \\ []) do
    :telemetry.span([:kjogvi, :legacy, :import, :prepare], telemetry_metadata(opts), fn ->
      Kjogvi.Legacy.Import.Observations.truncate()
      Kjogvi.Legacy.Import.Cards.truncate()
      Kjogvi.Legacy.Import.Locations.truncate()

      {:ok, telemetry_metadata(opts)}
    end)
  end

  def perform_import(object_type, opts \\ []) do
    :telemetry.span([:kjogvi, :legacy, :import, object_type], telemetry_metadata(opts), fn ->
      result = load(object_type, adapter().init(), {1, 0}, opts)

      {result, telemetry_metadata(opts)}
    end)
  end

  defp load(object_type, fetcher, {page, loaded}, opts) do
    results = adapter().fetch_page(object_type, fetcher, page)

    if Enum.empty?(results.rows) do
      after_import(object_type, opts)
      :ok
    else
      put_loaded(object_type, results.columns, results.rows, opts)
      count = loaded + length(results.rows)

      :telemetry.execute(
        [:kjogvi, :legacy, :import, object_type, :progress],
        %{count: count},
        telemetry_metadata(opts)
      )

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
    :telemetry.span(
      [:kjogvi, :legacy, :import, :locations, :after_import],
      telemetry_metadata(opts),
      fn ->
        Kjogvi.Legacy.Import.Locations.after_import()

        {:ok, telemetry_metadata(opts)}
      end
    )
  end

  defp after_import(:cards, _opts) do
    # Kjogvi.Legacy.Import.Cards.after_import()
  end

  defp after_import(:observations, opts) do
    :telemetry.span(
      [:kjogvi, :legacy, :import, :observations, :after_import],
      telemetry_metadata(opts),
      fn ->
        Kjogvi.Legacy.Import.Observations.after_import()

        {:ok, telemetry_metadata(opts)}
      end
    )
  end

  def config do
    Application.get_env(:kjogvi, :legacy)
  end

  defp adapter do
    config()[:adapter]
  end

  defp telemetry_metadata(opts) do
    %{adapter: adapter(), user_id: opts[:user].id, import_id: opts[:import_id]}
  end
end
