defmodule Kjogvi.Telemetry.Opentelemetry.TaxonomyImport do
  @moduledoc """
  Bridges the taxonomy import's `[:ornitho, :import, _]` telemetry span to
  OpenTelemetry.

  The import runs inside the ornithologue library (see `Ornitho.Importer`), but
  telemetry handlers are global per-VM, so kjogvi can attach to its events here.
  """

  alias Kjogvi.Telemetry.Opentelemetry.Span

  def setup() do
    config = %{
      tracer_id: __MODULE__,
      span_name: "ornitho.import"
    }

    :telemetry.attach_many(
      __MODULE__,
      [
        [:ornitho, :import, :start],
        [:ornitho, :import, :stop],
        [:ornitho, :import, :exception]
      ],
      &__MODULE__.handle_event/4,
      config
    )
  end

  def handle_event(
        [:ornitho, :import, :start],
        %{monotonic_time: start_time},
        metadata,
        %{tracer_id: tracer_id, span_name: span_name}
      ) do
    Span.start(tracer_id, span_name, metadata, start_time)
  end

  def handle_event(
        [:ornitho, :import, :stop],
        %{duration: duration},
        metadata,
        %{tracer_id: tracer_id}
      ) do
    Span.stop(tracer_id, metadata, duration)
  end

  def handle_event(
        [:ornitho, :import, :exception],
        %{duration: duration},
        %{reason: reason, stacktrace: stacktrace} = metadata,
        %{tracer_id: tracer_id}
      ) do
    Span.exception(tracer_id, metadata, reason, stacktrace, duration)
  end

  def handle_event(_event, _measurements, _metadata, _config), do: :ok
end
