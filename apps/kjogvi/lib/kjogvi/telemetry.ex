defmodule Kjogvi.Telemetry do
  def setup do
    Kjogvi.Telemetry.Logger.install()
    Kjogvi.Telemetry.Logger.dev_setup()

    Kjogvi.Telemetry.Opentelemetry.setup()
  end
end
