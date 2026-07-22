defmodule Kjogvi.Ebird.Import do
  @moduledoc """
  Imports observations from an eBird "Download My Data" export.

  eBird ships the export as a `.zip` holding a single `MyEBirdData.csv`. The
  import job (`Kjogvi.Jobs.Ebird.Import`) unpacks the zip to a scratch dir and
  hands the CSV path here.

  ## Shape of the data

  eBird orders the CSV by taxonomy, not by checklist, so a submission's rows are
  scattered through the file. Each row is unique per (`Submission ID`, species)
  and repeats the checklist-wide fields (date, effort, location). Rows are
  grouped back into checklists here, one `Checklist` per `Submission ID` with its
  observations built via `cast_assoc`.

  ## What the import does

    * **Locations.** Every distinct `Location ID` is upserted into
      `Kjogvi.Ebird.UserLocation` (the user's own eBird-location table). A user
      location already mapped to a real `Kjogvi.Geo.Location` reuses it;
      otherwise a `:site` is created and linked, placed under the common location
      the row's `State/Province` eBird region resolves to. When the state has no
      linked common location the user location is stored unmapped (no ancestor
      fallback) and its checklists are skipped (counted in `checklists_unmapped`)
      until the region is matched.

    * **Taxa.** Each row's `Scientific Name` is resolved against the user's
      taxonomy book (`default_book_signature`) into a `taxon_key`. A name with no
      match is skipped and reported — its checklist and other observations still
      import.

    * **Checklists.** Checklists whose `Submission ID` the user already has are
      skipped (there is no observation id in the export to reconcile against, so
      re-import only adds genuinely new submissions). New ones are inserted with
      their observations. A submission with no `Submission ID` at all is a
      malformed row: it's dropped and counted in `checklists_invalid`, kept
      distinct from the changeset failures that would signal a mapping bug.

    * **Promotion.** After the checklists are in, the user's observed taxa are
      promoted (`Kjogvi.Pages.Promotion`) so each imported species gets a page
      and appears in the lifelist — the direct inserts here bypass the per-write
      promotion that `Kjogvi.Birding.create_checklist/2` does.

  Returns `{:ok, summary}` where summary carries the counts and the collected
  `unresolved_taxa` (distinct unmatched scientific names) — or `{:error, reason}`
  when the user has no usable taxonomy book.
  """

  @error_counts [:checklists_unmapped, :checklists_invalid, :checklists_failed]

  require Logger

  alias Ecto.Changeset
  alias Kjogvi.Birding.Checklist
  alias Kjogvi.Birding.Observation
  alias Kjogvi.Ebird.CsvImport.Converter
  alias Kjogvi.Ebird.UserLocation
  alias Kjogvi.Geo.EbirdLocation
  alias Kjogvi.Geo.Location
  alias Kjogvi.Repo

  @doc """
  Runs the import against the CSV at `csv_path` for `user`.

  `opts` carries a `:broadcast_key` (the Oban job) for progress reporting; unused
  for now.
  """
  def run(user, csv_path, _opts \\ []) do
    with {:ok, book} <- resolve_book(user) do
      rows = parse_csv(csv_path)
      taxon_keys = resolve_taxon_keys(book, rows)
      location_ids = upsert_user_locations(user, rows)

      summary = import_checklists(user, rows, taxon_keys, location_ids)

      promote_observations(user)

      Logger.info(
        "eBird import: #{summary.checklists_created} checklists, " <>
          "#{summary.observations_created} observations for user #{user.id}"
      )

      {:ok, summary}
    end
  end

  defp resolve_book(%{default_book_signature: sig}) when is_binary(sig) and sig != "" do
    [slug, version] = String.split(sig, "/")

    case Ornitho.Finder.Book.by_signature(slug, version) do
      %Ornitho.Schema.Book{} = book -> {:ok, book}
      nil -> {:error, :book_not_found}
    end
  end

  defp resolve_book(_user), do: {:error, :no_default_book}

  @doc """
  Whether the summary of a finished run reports rows that were not imported
  (skipped duplicates don't count — they are already there).
  """
  def errors?(summary) do
    Enum.any?(@error_counts, &(Map.fetch!(summary, &1) > 0)) or summary.unresolved_taxa != []
  end

  # Reads every row into a list, keyed by the header line (`headers: true`).
  # Not incremental: rows are taxonomy-ordered, so a submission's rows are
  # scattered through the file and can only be regrouped (`import_checklists/4`)
  # once all are in hand. A "Download My Data" export is small enough (tens of MB
  # of small maps) that holding it all is fine.
  defp parse_csv(csv_path) do
    csv_path
    |> File.stream!()
    |> CSV.decode!(headers: true)
    |> Enum.to_list()
  end

  # `%{name_sci => taxon_key}` for the distinct scientific names in the CSV that
  # the book knows. All taxa are fetched once and indexed by name; names the book
  # doesn't carry (subspecies, spuhs, hybrids, …) are simply absent and reported
  # as unresolved when a row needs them.
  defp resolve_taxon_keys(book, rows) do
    wanted =
      rows
      |> Enum.map(&Converter.observation_attrs(&1).name_sci)
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()

    book
    |> Ornitho.Finder.Taxon.all()
    |> Enum.filter(&MapSet.member?(wanted, &1.name_sci))
    |> Map.new(&{&1.name_sci, Ornitho.Schema.Taxon.key(%{&1 | book: book})})
  end

  # Upserts one `UserLocation` per distinct `Location ID`, returning
  # `%{ebird_loc_id => location_id}` for the mapped real location (nil when the
  # state has no matched common location). An already-mapped user location keeps
  # its link; an existing but unmapped one is (re-)resolved now, so a location left
  # unmapped by an earlier run gets its site once its region is matchable.
  defp upsert_user_locations(user, rows) do
    existing = existing_user_locations(user, rows)
    parents = parent_locations(rows)

    rows
    |> distinct_location_attrs()
    |> Enum.map(fn attrs -> upsert_user_location(user, attrs, existing, parents) end)
    |> Map.new()
  end

  defp existing_user_locations(user, rows) do
    ebird_loc_ids = rows |> Enum.map(& &1["Location ID"]) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    UserLocation.Query.by_user(user)
    |> UserLocation.Query.by_ebird_loc_id(ebird_loc_ids)
    |> Repo.all()
    |> Map.new(&{&1.ebird_loc_id, &1})
  end

  # One representative attrs map per `ebird_loc_id` (the fields repeat across a
  # location's rows), dropping rows without a location id.
  defp distinct_location_attrs(rows) do
    rows
    |> Enum.map(&Converter.user_location_attrs/1)
    |> Enum.reject(&is_nil(&1.ebird_loc_id))
    |> Enum.uniq_by(& &1.ebird_loc_id)
  end

  # `%{state_code => common_location}` over the `State/Province` codes the CSV
  # needs that resolve to a linked common location. Codes with no linked location
  # are absent.
  defp parent_locations(rows) do
    codes =
      rows
      |> Enum.map(& &1["State/Province"])
      |> Enum.reject(&blank?/1)
      |> Enum.uniq()

    EbirdLocation.Query.by_codes(codes)
    |> EbirdLocation.Query.matched()
    |> Repo.all()
    |> Repo.preload(:location)
    |> Map.new(&{&1.code, &1.location})
  end

  defp upsert_user_location(user, attrs, existing, parents) do
    case Map.fetch(existing, attrs.ebird_loc_id) do
      # Already linked to a real location — keep it.
      {:ok, %UserLocation{location_id: location_id}} when not is_nil(location_id) ->
        {attrs.ebird_loc_id, location_id}

      # Exists but unmapped (an earlier run couldn't place it): resolve and link now.
      {:ok, %UserLocation{} = user_location} ->
        {:ok, updated} = link_user_location(user, user_location, attrs, parents)
        {attrs.ebird_loc_id, updated.location_id}

      :error ->
        {:ok, user_location} = insert_user_location(user, attrs, parents)
        {attrs.ebird_loc_id, user_location.location_id}
    end
  end

  # A new user location is linked to a fresh `:site` under the common location its
  # `State/Province` resolves to. When the state has no matched common location the
  # user location is stored unmapped (`location_id: nil`) — we don't place the site
  # under an ancestor as a fallback — and its checklists are skipped.
  defp insert_user_location(user, attrs, parents) do
    Repo.transact(fn ->
      with {:ok, location} <- create_site(user, attrs, resolve_parent(attrs.state, parents)) do
        attrs
        |> Map.put(:user_id, user.id)
        |> Map.put(:location_id, location && location.id)
        |> then(&UserLocation.changeset(%UserLocation{}, &1))
        |> Repo.insert()
      end
    end)
  end

  # Resolves an existing unmapped user location: creates its `:site` and links it.
  # Stays unmapped when the state still has no matched common location.
  defp link_user_location(user, user_location, attrs, parents) do
    Repo.transact(fn ->
      with {:ok, location} <- create_site(user, attrs, resolve_parent(attrs.state, parents)) do
        user_location
        |> UserLocation.changeset(%{location_id: location && location.id})
        |> Repo.update()
      end
    end)
  end

  defp resolve_parent(nil, _parents), do: nil
  defp resolve_parent(state_code, parents), do: Map.get(parents, state_code)

  # The state has no matched common location: leave the user location unmapped
  # rather than placing its site under an ancestor.
  defp create_site(_user, _attrs, nil), do: {:ok, nil}

  # The eBird location id (`"L956160"`) downcased is a stable, per-user-unique
  # slug: a letter plus digits, so it passes the slug format and length rules.
  defp create_site(user, attrs, parent) do
    site_attrs = %{
      slug: String.downcase(attrs.ebird_loc_id),
      name_en: attrs.name,
      location_type: :site,
      is_private: false,
      lat: attrs.lat,
      lon: attrs.lon,
      parent_id: parent.id
    }

    %Location{}
    |> Location.changeset(site_attrs)
    |> Changeset.put_change(:user_id, user.id)
    |> Changeset.put_change(:import_source, :ebird)
    |> Location.validate_user_owned_type()
    |> Location.validate_common_ancestry()
    |> Repo.insert()
  end

  # The import inserts checklists directly (bypassing `Birding.create_checklist/2`),
  # so the per-write promotion never runs. Promote the user's observed taxa once at
  # the end so every imported species gets a page and shows in the lifelist
  # (`Pages.Promotion` only touches taxa still lacking a mapping).
  defp promote_observations(user) do
    Observation.Query.with_checklist()
    |> Observation.Query.owned_by(user)
    |> Kjogvi.Pages.Promotion.promote_observations_by_query()
  end

  # Groups rows into submissions, skips submissions the user already has, and
  # inserts the rest — each checklist with its (resolvable) observations.
  defp import_checklists(user, rows, taxon_keys, location_ids) do
    by_submission = Enum.group_by(rows, & &1["Submission ID"])
    new_ids = new_submission_ids(user, Map.keys(by_submission))

    acc = %{
      checklists_created: 0,
      observations_created: 0,
      checklists_skipped: map_size(by_submission) - MapSet.size(new_ids),
      checklists_unmapped: 0,
      checklists_invalid: 0,
      checklists_failed: 0,
      unresolved_taxa: MapSet.new()
    }

    for {submission_id, submission_rows} <- by_submission,
        MapSet.member?(new_ids, submission_id),
        reduce: acc do
      acc -> insert_submission(user, submission_rows, taxon_keys, location_ids, acc)
    end
    |> Map.update!(:unresolved_taxa, &Enum.sort(MapSet.to_list(&1)))
  end

  # eBird submission ids we don't already have a checklist for.
  defp new_submission_ids(user, submission_ids) do
    Checklist
    |> Checklist.Query.as_checklist()
    |> Checklist.Query.by_user(user)
    |> Checklist.Query.find_new_checklists(submission_ids)
    |> Repo.all()
    |> MapSet.new()
  end

  defp insert_submission(user, rows, taxon_keys, location_ids, acc) do
    [first | _] = rows

    case Converter.checklist_attrs(first) do
      # A blank Submission ID is a malformed export row, not a mapping bug:
      # count it apart from the changeset failures in `insert_checklist`.
      {:error, :missing_submission_id} ->
        Map.update!(acc, :checklists_invalid, &(&1 + 1))

      {:ok, attrs} ->
        {observations, unresolved} = build_observations(rows, taxon_keys)
        acc = Map.update!(acc, :unresolved_taxa, &MapSet.union(&1, unresolved))

        case Map.get(location_ids, first["Location ID"]) do
          nil -> Map.update!(acc, :checklists_unmapped, &(&1 + 1))
          location_id -> insert_checklist(user, attrs, location_id, observations, acc)
        end
    end
  end

  defp insert_checklist(user, attrs, location_id, observations, acc) do
    attrs =
      attrs
      |> Map.put(:user_id, user.id)
      |> Map.put(:location_id, location_id)
      |> Map.put(:observations, observations)

    # `ebird_id` and `import_source` aren't in the checklist form's cast list
    # (they're import metadata, not user-editable), so set them directly.
    changeset =
      %Checklist{}
      |> Checklist.changeset(attrs)
      |> Changeset.put_change(:ebird_id, attrs.ebird_id)
      |> Changeset.put_change(:import_source, :ebird)

    case Repo.insert(changeset) do
      {:ok, checklist} ->
        acc
        |> Map.update!(:checklists_created, &(&1 + 1))
        |> Map.update!(:observations_created, &(&1 + length(checklist.observations)))

      {:error, changeset} ->
        Logger.warning(
          "eBird import: skipping checklist #{attrs.ebird_id}: " <>
            inspect(changeset_errors(changeset))
        )

        Map.update!(acc, :checklists_failed, &(&1 + 1))
    end
  end

  # Observation attrs for a submission's rows, resolving each row's scientific
  # name to a taxon key. Rows whose name the book doesn't know are dropped and
  # their names collected as unresolved.
  defp build_observations(rows, taxon_keys) do
    Enum.reduce(rows, {[], MapSet.new()}, fn row, acc ->
      add_observation(Converter.observation_attrs(row), taxon_keys, acc)
    end)
  end

  # A row with no scientific name isn't an observation at all (blank/malformed);
  # drop it silently rather than reporting nil as unresolved.
  defp add_observation(%{name_sci: nil}, _taxon_keys, acc), do: acc

  defp add_observation(%{name_sci: name_sci} = attrs, taxon_keys, {obs, unresolved}) do
    case Map.fetch(taxon_keys, name_sci) do
      {:ok, taxon_key} -> {[obs_attrs(attrs, taxon_key) | obs], unresolved}
      :error -> {obs, MapSet.put(unresolved, name_sci)}
    end
  end

  defp obs_attrs(attrs, taxon_key) do
    attrs
    |> Map.drop([:name_sci])
    |> Map.put(:taxon_key, taxon_key)
  end

  defp changeset_errors(changeset) do
    Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
end
