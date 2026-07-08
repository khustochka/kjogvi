defmodule Kjogvi.Telemetry.Logger do
  @moduledoc """
  Instrumenter to handle logging of application-specific events.
  """

  require Logger

  @doc """
  Initializers logger hooks.
  """
  def install do
    handlers = %{
      [:kjogvi, :legacy, :import, :start] => &__MODULE__.legacy_import_start/4,
      [:kjogvi, :legacy, :import, :stop] => &__MODULE__.legacy_import_stop/4,
      [:kjogvi, :geo, :import, :start] => &__MODULE__.geo_import_start/4,
      [:kjogvi, :geo, :import, :stop] => &__MODULE__.geo_import_stop/4,
      [:kjogvi, :geo, :dump, :stop] => &__MODULE__.geo_dataset_stop/4,
      [:kjogvi, :geo, :restore, :stop] => &__MODULE__.geo_dataset_stop/4
    }

    for {key, fun} <- handlers do
      :telemetry.attach({__MODULE__, key}, key, fun, :ok)
    end
  end

  @doc false
  def legacy_import_start(_, _, metadata, _) do
    Logger.info("[Kjogvi.Legacy.Import] Started: adapter=#{metadata[:adapter]}.", metadata)
  end

  @doc false
  def legacy_import_stop(_, %{duration: duration}, %{error: reason} = metadata, _) do
    Logger.error(
      "[Kjogvi.Legacy.Import] Failed after #{duration_ms(duration)}ms: #{inspect(reason)}",
      metadata
    )
  end

  def legacy_import_stop(_, %{duration: duration}, metadata, _) do
    Logger.info("[Kjogvi.Legacy.Import] Finished: duration=#{duration_ms(duration)}ms", metadata)
  end

  @doc false
  def geo_import_start(_, _, metadata, _) do
    Logger.info("[Kjogvi.Geo.Import] Started.", metadata)
  end

  @doc false
  def geo_import_stop(_, %{duration: duration}, %{result: :error, reason: reason} = metadata, _) do
    Logger.error(
      "[Kjogvi.Geo.Import] Failed after #{duration_ms(duration)}ms: #{inspect(reason)}",
      metadata
    )
  end

  def geo_import_stop(_, %{duration: duration}, %{count: count} = metadata, _) do
    Logger.info(
      "[Kjogvi.Geo.Import] Finished: #{count} locations in #{duration_ms(duration)}ms",
      metadata
    )
  end

  @doc false
  def geo_dataset_stop(
        [:kjogvi, :geo, op, :stop],
        %{duration: duration},
        %{result: :error, reason: reason} = metadata,
        _
      ) do
    Logger.error(
      "[#{dataset_op(op)}] #{metadata[:dataset]} failed after #{duration_ms(duration)}ms: #{inspect(reason)}",
      metadata
    )
  end

  def geo_dataset_stop(
        [:kjogvi, :geo, op, :stop],
        %{duration: duration},
        %{count: count} = metadata,
        _
      ) do
    Logger.info(
      "[#{dataset_op(op)}] #{metadata[:dataset]}: #{count} rows in #{duration_ms(duration)}ms",
      metadata
    )
  end

  defp dataset_op(:dump), do: "Kjogvi.Geo.Dump"
  defp dataset_op(:restore), do: "Kjogvi.Geo.Restore"

  defp duration_ms(duration), do: System.convert_time_unit(duration, :native, :millisecond)

  def dev_setup do
    ecto_dev_logger(
      log_repo_name: true,
      before_inline_callback: &Kjogvi.Util.SQLFormatter.format/1
    )
  end

  if Code.ensure_loaded?(Ecto.DevLogger) do
    defp ecto_dev_logger(opts) do
      Ecto.DevLogger.install(Kjogvi.Repo, opts)
    end
  else
    defp ecto_dev_logger(_), do: :ok
  end
end
