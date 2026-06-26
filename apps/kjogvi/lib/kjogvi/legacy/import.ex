defmodule Kjogvi.Legacy.Import do
  @moduledoc false

  require Logger

  def run(user, opts \\ []) do
    with :ok <- validate(user),
         :ok <- validate_adapter_config() do
      opts
      |> Keyword.put(:user, user)
      |> import_all()
    end
  end

  defp validate(%{default_book_signature: sig}) when is_binary(sig) and sig != "" do
    :ok
  end

  defp validate(_user) do
    {:error,
     %{
       message:
         "Legacy import requires a default taxonomy. " <>
           "Set it in account settings before running the import."
     }}
  end

  # Lets the configured adapter check its own required config (DB connection,
  # remote URL/API key, ...) up front, so a misconfiguration surfaces as a
  # friendly `{:error, %{message: ...}}` instead of an opaque crash deep inside
  # the import. Adapters that need nothing return `:ok` (the default).
  defp validate_adapter_config do
    adapter = adapter()

    if function_exported?(adapter, :validate_config, 0) do
      adapter.validate_config()
    else
      :ok
    end
  end

  defp import_all(opts) do
    :telemetry.span([:kjogvi, :legacy, :import], telemetry_metadata(opts), fn ->
      result =
        Kjogvi.Repo.transact(
          fn ->
            with :ok <- prepare_import(opts),
                 :ok <- perform_import(:locations, opts),
                 :ok <- perform_import(:checklists, opts),
                 :ok <- perform_import(:observations, opts),
                 # Images are imported last: they link back to observations
                 # (see Kjogvi.Legacy.Import.Images).
                 :ok <- perform_import(:images, opts) do
              {:ok, %{message: "Legacy import done."}}
            else
              {:error, error} = err ->
                Logger.error("""
                #{inspect(__MODULE__)}: failed with error:
                #{inspect(error)}
                """)

                err
            end
          end,
          timeout: query_timeout()
        )

      {result, stop_metadata(result, opts)}
    end)
  end

  def prepare_import(opts \\ []) do
    :telemetry.span([:kjogvi, :legacy, :import, :prepare], telemetry_metadata(opts), fn ->
      result =
        with {:ok, _} <- Kjogvi.Legacy.Import.Images.cleanup(),
             {:ok, _} <- Kjogvi.Legacy.Import.Observations.cleanup(),
             {:ok, _} <- Kjogvi.Legacy.Import.Checklists.cleanup(),
             {:ok, _} <- Kjogvi.Legacy.Import.Locations.cleanup() do
          :ok
        end

      {result, stop_metadata(result, opts)}
    end)
  end

  def perform_import(object_type, opts \\ [])

  # Locations are imported in a single shot rather than page by page: resolving
  # each location's level FKs and special-children means walking its ancestry,
  # whose ancestors may sit anywhere in the set, so the whole set must be in hand
  # at once. The legacy dataset is well under one page (`@per_page`), so a single
  # `fetch_page` holds it all; a second non-empty page would mean the dataset
  # outgrew that assumption, so we fail loudly rather than silently truncate.
  def perform_import(:locations, opts) do
    :telemetry.span([:kjogvi, :legacy, :import, :locations], telemetry_metadata(opts), fn ->
      result = load_all_at_once(:locations, opts)

      {result, stop_metadata(result, opts)}
    end)
  end

  def perform_import(object_type, opts) do
    :telemetry.span([:kjogvi, :legacy, :import, object_type], telemetry_metadata(opts), fn ->
      result = load(object_type, adapter().init(), {1, 0}, opts)

      {result, stop_metadata(result, opts)}
    end)
  end

  defp load_all_at_once(object_type, opts) do
    fetcher = adapter().init()
    first = adapter().fetch_page(object_type, fetcher, 1)

    if Enum.empty?(adapter().fetch_page(object_type, fetcher, 2).rows) do
      with :ok <- put_loaded(object_type, first.columns, first.rows, opts) do
        after_import(object_type, opts)
      end
    else
      raise "Legacy #{object_type} import expects a single page; the dataset has more than one."
    end
  end

  defp load(object_type, fetcher, {page, loaded}, opts) do
    results = adapter().fetch_page(object_type, fetcher, page)

    if Enum.empty?(results.rows) do
      after_import(object_type, opts)
    else
      with :ok <- put_loaded(object_type, results.columns, results.rows, opts) do
        count = loaded + length(results.rows)

        :telemetry.execute(
          [:kjogvi, :legacy, :import, object_type, :progress],
          %{count: count},
          telemetry_metadata(opts)
        )

        load(object_type, fetcher, {page + 1, count}, opts)
      end
    end
  end

  defp put_loaded(:locations, columns, rows, opts) do
    Kjogvi.Legacy.Import.Locations.import(columns, rows, opts)
  end

  defp put_loaded(:checklists, columns, rows, opts) do
    Kjogvi.Legacy.Import.Checklists.import(columns, rows, opts)
  end

  defp put_loaded(:observations, columns, rows, opts) do
    Kjogvi.Legacy.Import.Observations.import(columns, rows, opts)
  end

  defp put_loaded(:images, columns, rows, opts) do
    Kjogvi.Legacy.Import.Images.import(columns, rows, opts)
  end

  defp after_import(:locations, _opts) do
    :ok
  end

  defp after_import(:checklists, _opts) do
    :ok
  end

  defp after_import(:observations, opts) do
    :telemetry.span(
      [:kjogvi, :legacy, :import, :observations, :after_import],
      telemetry_metadata(opts),
      fn ->
        result = Kjogvi.Legacy.Import.Observations.after_import(opts)

        {result, telemetry_metadata(opts)}
      end
    )
  end

  defp after_import(:images, _opts) do
    :ok
  end

  def config do
    Application.get_env(:kjogvi, __MODULE__)
  end

  # Bounds the whole import transaction (`import_all/1`). Configured via
  # `:query_timeout` (`LEGACY_QUERY_TIMEOUT`, default 30s in config.exs).
  defp query_timeout do
    Keyword.fetch!(config(), :query_timeout)
  end

  defp adapter do
    config()
    |> Keyword.fetch!(:adapter)
  end

  defp telemetry_metadata(opts) do
    broadcast_key = opts[:broadcast_key] || "legacy_import:#{opts[:user].id}"
    %{adapter: adapter(), user_id: opts[:user].id, broadcast_key: broadcast_key}
  end

  # `:telemetry.span/3` has no error event for a handled `{:error, _}` (only crashes
  # emit `:exception`), so carry the reason in an `:error` key to let handlers tell a
  # failed `:stop` from a successful one.
  defp stop_metadata(result, opts) do
    metadata = telemetry_metadata(opts)

    case result do
      {:error, reason} -> Map.put(metadata, :error, reason)
      _ -> metadata
    end
  end
end
