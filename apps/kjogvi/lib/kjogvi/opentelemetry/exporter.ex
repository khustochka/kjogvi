defmodule Kjogvi.Opentelemetry.Exporter do
  @behaviour :otel_exporter

  @impl true
  def init(opts) do
    :opentelemetry_exporter.init(Enum.into(opts, %{}))
  end

  @impl true
  def export(:traces, spans_tid, resource, config) do
    :opentelemetry_exporter.export(:traces, spans_tid, resource, config)
  end

  @impl true
  def shutdown(state) do
    :opentelemetry_exporter.shutdown(state)
  end
end
