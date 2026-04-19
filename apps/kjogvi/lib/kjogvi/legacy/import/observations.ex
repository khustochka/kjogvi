defmodule Kjogvi.Legacy.Import.Observations do
  @moduledoc false

  alias Kjogvi.Repo
  alias Kjogvi.Birding.Observation

  def import(columns_str, rows, opts) do
    columns = columns_str |> Enum.map(&String.to_atom/1)
    book_signature = book_signature!(opts)

    obs =
      for row <- rows do
        Enum.zip(columns, row)
        |> Map.new()
        |> transform_keys(book_signature)
      end

    _ = Repo.insert_all(Observation, obs)

    Repo.query!("SELECT setval('observations_id_seq', (SELECT MAX(id) FROM observations));")
  end

  def after_import do
    # Promoting
    Kjogvi.Pages.Promotion.promote_observations_by_query(Observation)

    # Legacy imports bypass `Kjogvi.Birding.create_card/2`, so the per-write
    # log cache invalidation doesn't run. Evict the main user's log cache
    # once at the tail of the pipeline — legacy imports target the
    # single-user site owner.
    case Kjogvi.Settings.main_user() do
      nil -> :ok
      user -> Kjogvi.Birding.Log.Cache.invalidate(user.id)
    end
  end

  def truncate do
    _ = Repo.query!("TRUNCATE observations;")
    _ = Repo.query!("ALTER SEQUENCE observations_id_seq RESTART;")
  end

  defp transform_keys(%{ebird_code: "unrepbirdsp"} = obs, book_signature) do
    %{obs | ebird_code: "bird1"}
    |> Map.put(:unreported, true)
    |> transform_keys(book_signature)
  end

  defp transform_keys(
         %{created_at: created_at, updated_at: updated_at, ebird_code: ebird_code} = obs,
         book_signature
       ) do
    obs
    |> Map.drop([:created_at, :post_id, :taxon_id, :ebird_code])
    |> Map.put(:taxon_key, "/#{book_signature}/#{ebird_code}")
    |> Map.put(:inserted_at, convert_timestamp(created_at))
    |> Map.put(:updated_at, convert_timestamp(updated_at))
  end

  defp convert_timestamp(nil) do
    nil
  end

  defp convert_timestamp(%NaiveDateTime{} = time) do
    {:ok, converted} = DateTime.from_naive(time, "Etc/UTC")
    converted
  end

  defp convert_timestamp(time) when is_binary(time) do
    {:ok, dt, _} = DateTime.from_iso8601(time)
    {usec, _} = dt.microsecond
    %{dt | microsecond: {usec, 6}}
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
