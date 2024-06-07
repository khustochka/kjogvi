defmodule Kjogvi.Logger do
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
      [:kjogvi, :legacy, :import, :stop] => &__MODULE__.legacy_import_stop/4
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
  def legacy_import_stop(_, %{duration: duration}, metadata, _) do
    # See also Phoenix.Logger.duration for improvements
    Logger.info(
      "[Kjogvi.Legacy.Import] Finished: duration=#{System.convert_time_unit(duration, :native, :millisecond)}ms",
      metadata
    )
  end
end
