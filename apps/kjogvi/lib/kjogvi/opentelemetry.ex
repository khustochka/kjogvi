defmodule Kjogvi.Opentelemetry do
  @moduledoc """
  Opentelemetry setup with customizations specific to the Kjogvi project.
  """

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
        [:kjogvi, :legacy, :import, :exception],
        [:kjogvi, :legacy, :import, :prepare, :start],
        [:kjogvi, :legacy, :import, :prepare, :stop],
        [:kjogvi, :legacy, :import, :prepare, :exception],
        [:kjogvi, :legacy, :import, :locations, :start],
        [:kjogvi, :legacy, :import, :locations, :stop],
        [:kjogvi, :legacy, :import, :locations, :exception],
        [:kjogvi, :legacy, :import, :cards, :start],
        [:kjogvi, :legacy, :import, :cards, :stop],
        [:kjogvi, :legacy, :import, :cards, :exception],
        [:kjogvi, :legacy, :import, :observations, :start],
        [:kjogvi, :legacy, :import, :observations, :stop],
        [:kjogvi, :legacy, :import, :observations, :exception]
      ],
      &__MODULE__.handle_event/4,
      config
    )
  end

  def handle_event(
        [:kjogvi, :legacy, :import, :start],
        %{monotonic_time: start_time},
        metadata,
        %{tracer_id: tracer_id, span_name: span_name}
      ) do
    start_span(tracer_id, span_name, metadata, start_time)
  end

  def handle_event(
        [:kjogvi, :legacy, :import, obj, :start],
        %{monotonic_time: start_time},
        metadata,
        %{tracer_id: tracer_id}
      ) do
    span_name = "kjogvi.legacy.import.#{obj}"

    start_span(tracer_id, span_name, metadata, start_time)
  end

  def handle_event(
        [:kjogvi, :legacy, :import, :stop],
        %{duration: duration},
        metadata,
        %{tracer_id: tracer_id}
      ) do
    end_span(tracer_id, metadata, duration)
  end

  def handle_event(
        [:kjogvi, :legacy, :import, _, :stop],
        %{duration: duration},
        metadata,
        %{tracer_id: tracer_id}
      ) do
    end_span(tracer_id, metadata, duration)
  end

  def handle_event(
        [:kjogvi, :legacy, :import, :exception],
        %{duration: duration},
        %{reason: reason, stacktrace: stacktrace} = metadata,
        %{tracer_id: tracer_id}
      ) do
    handle_exception(tracer_id, metadata, reason, stacktrace, duration)
  end

  def handle_event(
        [:kjogvi, :legacy, :import, _, :exception],
        %{duration: duration},
        %{reason: reason, stacktrace: stacktrace} = metadata,
        %{tracer_id: tracer_id}
      ) do
    handle_exception(tracer_id, metadata, reason, stacktrace, duration)
  end

  def handle_event(_event, _measurements, _metadata, _config), do: :ok

  defp start_span(tracer_id, span_name, metadata, start_time) do
    OpentelemetryTelemetry.start_telemetry_span(tracer_id, span_name, metadata, %{
      links: [],
      attributes: metadata,
      start_time: start_time,
      is_recording: false,
      kind: :internal
    })
  end

  defp end_span(tracer_id, metadata, duration) do
    OpentelemetryTelemetry.set_current_telemetry_span(tracer_id, metadata)

    OpenTelemetry.Tracer.set_attribute(:duration, duration)

    OpentelemetryTelemetry.end_telemetry_span(tracer_id, metadata)
  end

  defp handle_exception(tracer_id, metadata, reason, stacktrace, duration) do
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(tracer_id, metadata)
    status = OpenTelemetry.status(:error, inspect(reason))

    OpenTelemetry.Span.record_exception(ctx, reason, stacktrace, duration: duration)

    OpenTelemetry.Tracer.set_status(status)
    OpentelemetryTelemetry.end_telemetry_span(tracer_id, metadata)
  end
end
