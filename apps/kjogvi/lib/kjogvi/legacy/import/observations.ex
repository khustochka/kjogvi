defmodule Kjogvi.Legacy.Import.Observations do
  @moduledoc false

  alias Kjogvi.Legacy.Import.Utils
  alias Kjogvi.Repo
  alias Kjogvi.Birding.Checklist
  alias Kjogvi.Birding.Observation

  @blank_to_nil_columns [:quantity, :notes, :private_notes, :ebird_obs_id]

  @min_start_seq 100_000

  def import(columns_str, rows, opts) do
    columns = columns_str |> Enum.map(&String.to_atom/1)
    book_signature = book_signature!(opts)

    raw = for row <- rows, do: Map.new(Enum.zip(columns, row))
    checklist_times = checklist_times(raw)

    obs = for attrs <- raw, do: transform_keys(attrs, book_signature, checklist_times)

    with {_, _} <- Repo.insert_all(Observation, obs),
         {:ok, _} <-
           Repo.query(
             "SELECT setval('observations_id_seq', GREATEST(#{@min_start_seq}, (SELECT COALESCE(MAX(id), 0) FROM observations)));"
           ) do
      :ok
    end
  end

  def after_import(opts) do
    # Legacy imports bypass `Kjogvi.Birding.create_checklist/2`, so the per-write
    # logbook cache invalidation doesn't run. Evict the user's logbook cache.
    Kjogvi.Birding.Logbook.Cache.invalidate(opts[:user].id)

    # Promoting: create species pages for the imported user's observed taxa so
    # each species shows in the lifelist (the direct inserts here bypass the
    # per-write promotion in `Kjogvi.Birding.create_checklist/2`).
    Observation.Query.with_checklist()
    |> Observation.Query.owned_by(opts[:user])
    |> Kjogvi.Pages.Promotion.promote_observations_by_query()

    :ok
  end

  def cleanup do
    Kjogvi.Repo.query("DELETE FROM observations WHERE import_source='legacy';")
  end

  # Checklist timestamps keyed by checklist id, for the checklists referenced in this batch.
  # Checklists are imported before observations and always have non-null timestamps,
  # so they're the fallback for legacy observations missing created_at/updated_at.
  defp checklist_times(raw) do
    checklist_ids = raw |> Enum.map(& &1.card_id) |> Enum.uniq()

    Checklist.Query.timestamps_by_id(checklist_ids)
    |> Repo.all()
    |> Map.new()
  end

  defp transform_keys(%{ebird_code: "unrepbirdsp"} = obs, book_signature, checklist_times) do
    %{obs | ebird_code: "bird1"}
    |> Map.put(:unreported, true)
    |> transform_keys(book_signature, checklist_times)
  end

  defp transform_keys(
         %{created_at: created_at, updated_at: updated_at, ebird_code: ebird_code} = obs,
         book_signature,
         checklist_times
       ) do
    {checklist_inserted_at, checklist_updated_at} =
      Map.get(checklist_times, obs.card_id, {nil, nil})

    obs
    |> Map.take([
      :id,
      :hidden,
      :quantity,
      :voice,
      :notes,
      :ebird_obs_id,
      :private_notes
    ])
    |> Map.put(:checklist_id, obs.card_id)
    |> Map.put(:taxon_key, "/#{book_signature}/#{ebird_code}")
    # Many legacy observations have no created_at/updated_at; fall back to the checklist's.
    |> Map.put(:inserted_at, Utils.convert_timestamp(created_at) || checklist_inserted_at)
    |> Map.put(:updated_at, Utils.convert_timestamp(updated_at) || checklist_updated_at)
    |> Map.put(:import_source, :legacy)
    |> normalize_text_columns()
  end

  defp normalize_text_columns(obs) do
    Enum.reduce(@blank_to_nil_columns, obs, fn key, acc ->
      Map.update(acc, key, nil, &Utils.blank_to_nil/1)
    end)
  end

  defp book_signature!(opts) do
    case Keyword.get(opts, :user) do
      %{default_book_signature: sig} when is_binary(sig) and sig != "" ->
        sig

      %{default_book_signature: _} ->
        raise ArgumentError,
              "Legacy import requires the user to have `default_book_signature` set. " <>
                "Configure it in account settings."

      _ ->
        raise ArgumentError, "Legacy import requires a :user option"
    end
  end
end
