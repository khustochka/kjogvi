defmodule Kjogvi.Telemetry.Sampler do
  require OpenTelemetry.Tracer, as: Tracer
  require Logger

  @behaviour :otel_sampler

  # source: https://arathunku.com/b/2024/notes-on-adding-opentelemetry-to-an-elixir-app/
  @ignored_get_paths ~r/^\/(assets\/|fonts\/|live\/|phoenix\/|dev\/|favicon|site\.webmanifest).*/

  @impl :otel_sampler
  def setup(_sampler_opts), do: []

  @impl :otel_sampler
  def description(_sampler_config), do: "Kjogvi.Sampler"

  @impl :otel_sampler
  def should_sample(
        ctx,
        _trace_id,
        _links,
        span_name,
        span_kind,
        attributes,
        _sampler_config
      ) do
    result = drop_trace?(span_name, attributes)
    Logger.debug(fn ->
      "TRACE drop=#{result} span_names=#{span_name} kind=#{span_kind}"
    end)

    tracestate = Tracer.current_span_ctx(ctx) |> OpenTelemetry.Span.tracestate()

    case result do
      true ->
        {:drop, [], tracestate}

      false ->
        {:record_and_sample, [], tracestate}
    end
  end

  def drop_trace?(span_name, attributes) do
    cond do
      # I don't care about WS connection
      span_name == "Websocket" -> true
      # dev only but filter out to reduce noise
      # span_name == "kjogvi.repo.query:schema_migrations" -> true

      String.starts_with?(span_name, "HTTP GET") && (attributes[:"http.target"] || "") =~ @ignored_get_paths -> true
      true -> false
    end
  end
end
