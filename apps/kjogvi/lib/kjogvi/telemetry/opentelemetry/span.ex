defmodule Kjogvi.Telemetry.Opentelemetry.Span do
  @moduledoc """
  Helpers shared by the telemetry-to-OpenTelemetry bridges, turning
  `:telemetry.span/3` start/stop/exception events into OpenTelemetry spans.
  """

  def start(tracer_id, span_name, metadata, start_time) do
    OpentelemetryTelemetry.start_telemetry_span(tracer_id, span_name, metadata, %{
      links: [],
      attributes: metadata,
      start_time: start_time,
      is_recording: false,
      kind: :internal
    })
  end

  def stop(tracer_id, metadata, duration) do
    OpentelemetryTelemetry.set_current_telemetry_span(tracer_id, metadata)

    OpenTelemetry.Tracer.set_attribute(:duration, duration)

    # A handled failure surfaces as a `:stop` carrying an `:error` reason; mark the
    # span errored.
    case metadata do
      %{error: reason} ->
        OpenTelemetry.Tracer.set_status(OpenTelemetry.status(:error, inspect(reason)))

      _ ->
        :ok
    end

    OpentelemetryTelemetry.end_telemetry_span(tracer_id, metadata)
  end

  def exception(tracer_id, metadata, reason, stacktrace, duration) do
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(tracer_id, metadata)
    status = OpenTelemetry.status(:error, inspect(reason))

    OpenTelemetry.Span.record_exception(ctx, reason, stacktrace, duration: duration)

    OpenTelemetry.Tracer.set_status(status)
    OpentelemetryTelemetry.end_telemetry_span(tracer_id, metadata)
  end
end
