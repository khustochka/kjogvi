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

  def dev_setup do
    ecto_dev_logger(
      log_repo_name: true,
      before_inline_callback: &Kjogvi.Util.SQLFormatter.format/1
    )
  end

  if Code.ensure_loaded?(Ecto.DevLogger) do
    defp ecto_dev_logger(opts) do
      Ecto.DevLogger.install(Kjogvi.Repo, opts)
      Ecto.DevLogger.install(Kjogvi.OrnithoRepo, opts)
    end
  else
    defp ecto_dev_logger(_), do: :ok
  end
end
