defmodule Kjogvi.Opentelemetry do
  def setup() do
    Kjogvi.Opentelemetry.Ecto.setup()

    setup_legacy_import()
  end

  def setup_legacy_import() do
    config = %{
      tracer_id: __MODULE__,
      span_name: "kjogvi.legacy.import.run"
    }

    :telemetry.attach_many(
      {__MODULE__, :legacy_import},
      [
        [:kjogvi, :legacy, :import, :start],
        [:kjogvi, :legacy, :import, :stop],
        [:kjogvi, :legacy, :import, :exception]
      ],
      &__MODULE__.handle_event/4,
      config
    )
  end

  def handle_event(
        [:kjogvi, :legacy, :import, :start],
        %{monotonic_time: start_time},
        metadata,
        %{tracer_id: tracer_id, span_name: name}
      ) do
    start_opts = %{start_time: start_time, kind: :internal}

    OpentelemetryTelemetry.start_telemetry_span(tracer_id, name, metadata, start_opts)

    :ok
  end

  def handle_event(
        [:kjogvi, :legacy, :import, :stop],
        %{duration: duration},
        metadata,
        %{tracer_id: tracer_id}
      ) do
    OpentelemetryTelemetry.set_current_telemetry_span(tracer_id, metadata)

    OpenTelemetry.Tracer.set_attribute(:duration, duration)

    OpentelemetryTelemetry.end_telemetry_span(tracer_id, metadata)
    :ok
  end

  def handle_event(
        [:kjogvi, :legacy, :import, :exception],
        %{duration: duration},
        %{reason: reason, stacktrace: stacktrace} = metadata,
        %{tracer_id: tracer_id}
      ) do
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(tracer_id, metadata)
    status = OpenTelemetry.status(:error, inspect(reason))

    OpenTelemetry.Span.record_exception(ctx, reason, stacktrace, duration: duration)

    OpenTelemetry.Tracer.set_status(status)
    OpentelemetryTelemetry.end_telemetry_span(tracer_id, metadata)
    :ok
  end

  def handle_event(_event, _measurements, _metadata, _config), do: :ok
end
