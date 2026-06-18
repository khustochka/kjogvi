defmodule Ornitho.Importer.Telemetry do
  @moduledoc """
  Telemetry for taxonomy imports.

  `Ornitho.Importer.process_import/1` is wrapped in a `:telemetry.span/3`, which emits:

    * `[:ornitho, :import, :start]` — `%{system_time: ...}`,
      metadata `%{importer: module, telemetry_span_context: ...}`
    * `[:ornitho, :import, :stop]` — `%{duration: native_time}`,
      metadata `%{importer: module, taxa_count: integer | nil, ...}`; on a handled
      failure (`{:error, reason}` return) the metadata also carries `error: reason`
    * `[:ornitho, :import, :exception]` — `%{duration: native_time}`,
      metadata with `:kind`, `:reason`, `:stacktrace`, ...

  `attach_default_logger/1` attaches a handler that logs the start and duration of
  each import.
  """

  require Logger

  @start_event [:ornitho, :import, :start]
  @stop_event [:ornitho, :import, :stop]
  @exception_event [:ornitho, :import, :exception]

  @doc """
  Attaches a logger that reports the start and duration of each import at the given
  level (`:info` by default).
  """
  def attach_default_logger(level \\ :info) do
    :telemetry.attach_many(
      "ornitho-importer-logger",
      [@start_event, @stop_event, @exception_event],
      &__MODULE__.handle_event/4,
      %{level: level}
    )
  end

  @doc false
  def handle_event(@start_event, _measurements, metadata, %{level: level}) do
    Logger.log(level, "[Ornitho.Importer] #{inspect(metadata.importer)} started")
  end

  def handle_event(@stop_event, %{duration: duration}, %{error: reason} = metadata, _config) do
    Logger.error(
      "[Ornitho.Importer] #{inspect(metadata.importer)} failed after " <>
        "#{format_duration(duration)}: #{inspect(reason)}"
    )
  end

  def handle_event(@stop_event, %{duration: duration}, metadata, %{level: level}) do
    Logger.log(
      level,
      "[Ornitho.Importer] #{inspect(metadata.importer)} finished: " <>
        "#{metadata[:taxa_count]} taxa in #{format_duration(duration)}"
    )
  end

  def handle_event(@exception_event, %{duration: duration}, metadata, %{level: _level}) do
    Logger.error(
      "[Ornitho.Importer] #{inspect(metadata.importer)} failed after " <>
        "#{format_duration(duration)}: " <>
        "#{Exception.format(metadata.kind, metadata.reason, metadata.stacktrace)}"
    )
  end

  defp format_duration(native_time) do
    ms = System.convert_time_unit(native_time, :native, :millisecond)
    "#{Float.round(ms / 1000, 2)}s"
  end
end
