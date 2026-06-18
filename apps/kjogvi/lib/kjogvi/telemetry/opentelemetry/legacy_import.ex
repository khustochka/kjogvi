defmodule Kjogvi.Telemetry.Opentelemetry.LegacyImport do
  @moduledoc """
  Bridges the legacy import's `[:kjogvi, :legacy, :import, _]` telemetry spans to
  OpenTelemetry.
  """

  alias Kjogvi.Telemetry.Opentelemetry.Span

  def setup() do
    config = %{
      tracer_id: __MODULE__,
      span_name: "kjogvi.legacy.import.run"
    }

    :telemetry.attach_many(
      __MODULE__,
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
        [:kjogvi, :legacy, :import, :observations, :exception],
        [:kjogvi, :legacy, :import, :images, :start],
        [:kjogvi, :legacy, :import, :images, :stop],
        [:kjogvi, :legacy, :import, :images, :exception]
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
    Span.start(tracer_id, span_name, metadata, start_time)
  end

  def handle_event(
        [:kjogvi, :legacy, :import, obj, :start],
        %{monotonic_time: start_time},
        metadata,
        %{tracer_id: tracer_id}
      ) do
    Span.start(tracer_id, "kjogvi.legacy.import.#{obj}", metadata, start_time)
  end

  def handle_event(
        [:kjogvi, :legacy, :import, :stop],
        %{duration: duration},
        metadata,
        %{tracer_id: tracer_id}
      ) do
    Span.stop(tracer_id, metadata, duration)
  end

  def handle_event(
        [:kjogvi, :legacy, :import, _, :stop],
        %{duration: duration},
        metadata,
        %{tracer_id: tracer_id}
      ) do
    Span.stop(tracer_id, metadata, duration)
  end

  def handle_event(
        [:kjogvi, :legacy, :import, :exception],
        %{duration: duration},
        %{reason: reason, stacktrace: stacktrace} = metadata,
        %{tracer_id: tracer_id}
      ) do
    Span.exception(tracer_id, metadata, reason, stacktrace, duration)
  end

  def handle_event(
        [:kjogvi, :legacy, :import, _, :exception],
        %{duration: duration},
        %{reason: reason, stacktrace: stacktrace} = metadata,
        %{tracer_id: tracer_id}
      ) do
    Span.exception(tracer_id, metadata, reason, stacktrace, duration)
  end

  def handle_event(_event, _measurements, _metadata, _config), do: :ok
end
