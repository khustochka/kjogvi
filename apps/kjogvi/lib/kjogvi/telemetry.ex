defmodule Kjogvi.Telemetry do
  def setup do
    Kjogvi.Telemetry.Logger.install()
    Kjogvi.Telemetry.Logger.dev_setup()

    Kjogvi.Telemetry.Opentelemetry.setup()

    Kjogvi.Telemetry.LegacyBroadcast.setup()

    # Before the Bridge: the log row must be written before the lifecycle
    # broadcast that prompts LiveViews to reload it.
    Kjogvi.Imports.LogRecorder.setup()

    Kjogvi.Jobs.Runtime.Bridge.setup()
  end
end
