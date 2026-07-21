defmodule Kjogvi.Telemetry.Opentelemetry do
  @moduledoc """
  Opentelemetry setup with customizations specific to the Kjogvi project.
  """

  def setup() do
    Kjogvi.Opentelemetry.Ecto.setup()
    OpentelemetryOban.setup()

    Kjogvi.Telemetry.Opentelemetry.LegacyImport.setup()
    Kjogvi.Telemetry.Opentelemetry.TaxonomyImport.setup()
  end
end
