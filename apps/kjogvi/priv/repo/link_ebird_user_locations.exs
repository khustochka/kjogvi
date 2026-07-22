# Matches eBird submission IDs to checklists to link a user's ebird_user_locations
# to their app Geo.Locations. The eBird CSV maps submission -> eBird location; the
# checklists table maps submission (ebird_id) -> app location. Joining on submission
# yields (ebird_loc_id, app_location_id) pairs.
#
# A ebird_user_location is linked only on a true 1:1 relation: its eBird location maps
# to exactly one app location AND that app location maps to exactly one eBird location.
# Ambiguous relations (either side maps to 2+) are left unlinked and printed.
#
# Usage:
#   mix run apps/kjogvi/priv/repo/link_ebird_user_locations.exs "/path/to/MyEBirdData.csv" [user_id]

import Ecto.Query

alias Kjogvi.Repo
alias Kjogvi.Birding.Checklist
alias Kjogvi.Ebird.UserLocation

# Suppress Ecto's per-query debug SQL so only our report reaches stdout.
Logger.configure(level: :warning)

[path | rest] = System.argv()
user_id = rest |> List.first("1") |> String.to_integer()

# submission (ebird_id) -> app location_id, from this user's checklists
submission_to_app =
  Repo.all(
    from c in Checklist,
      where: c.user_id == ^user_id and not is_nil(c.ebird_id) and not is_nil(c.location_id),
      select: {c.ebird_id, c.location_id}
  )
  |> Map.new()

# (ebird_loc_id, app_location_id) -> checklist count, joined on submission. One CSV
# row per (submission, taxon), so count distinct submissions per pair, not rows.
pair_counts =
  path
  |> File.stream!()
  |> CSV.decode!(headers: true)
  |> Enum.reduce(%{}, fn row, acc ->
    case Map.fetch(submission_to_app, row["Submission ID"]) do
      {:ok, app_id} ->
        Map.update(
          acc,
          {row["Location ID"], app_id},
          MapSet.new([row["Submission ID"]]),
          &MapSet.put(&1, row["Submission ID"])
        )

      :error ->
        acc
    end
  end)
  |> Map.new(fn {pair, submissions} -> {pair, MapSet.size(submissions)} end)

pairs = Map.keys(pair_counts)

# ebird loc -> set of app locs, and app loc -> set of ebird locs
ebird_to_apps = Enum.group_by(pairs, &elem(&1, 0), &elem(&1, 1))
app_to_ebirds = Enum.group_by(pairs, &elem(&1, 1), &elem(&1, 0))

# id -> name lookups for display
ebird_names =
  Repo.all(
    from u in UserLocation,
      where: u.user_id == ^user_id,
      select: {u.ebird_loc_id, u.name}
  )
  |> Map.new()

app_names =
  Repo.all(from l in Kjogvi.Geo.Location, select: {l.id, l.name_en})
  |> Map.new()

ebird_label = fn id -> "#{id} #{ebird_names[id]}" end
app_label = fn id -> "#{id} #{app_names[id]}" end

now = DateTime.utc_now()

# True 1:1: the eBird loc maps to exactly one app loc, and that app loc maps back to
# exactly one eBird loc.
{to_link, ambiguous} =
  Enum.split_with(ebird_to_apps, fn {_ebird_loc, app_locs} ->
    case Enum.uniq(app_locs) do
      [app_id] -> length(Enum.uniq(app_to_ebirds[app_id])) == 1
      _ -> false
    end
  end)

# An app loc is "shared" if 2+ eBird locs map to it; an eBird loc is "shared" if it
# maps to 2+ app locs. A group is m:n when it has a shared side AND that side touches
# another shared node — i.e. both directions are ambiguous.
app_shared? = fn app_id -> length(Enum.uniq(app_to_ebirds[app_id])) > 1 end
ebird_shared? = fn ebird_loc -> length(Enum.uniq(ebird_to_apps[ebird_loc])) > 1 end

ebird_mn? = fn ebird_loc, app_locs ->
  length(app_locs) > 1 and Enum.any?(app_locs, app_shared?)
end

app_mn? = fn app_id, ebird_locs ->
  length(ebird_locs) > 1 and Enum.any?(ebird_locs, ebird_shared?)
end

# Section 1: m:n — both sides ambiguous, cross-referencing each other.
IO.puts("m:n — eBird and app locations that cross-reference each other (not linked):")

Enum.each(ambiguous, fn {ebird_loc, app_locs} ->
  app_locs = Enum.uniq(app_locs)

  if ebird_mn?.(ebird_loc, app_locs) do
    IO.puts("  eBird #{ebird_label.(ebird_loc)}")

    Enum.each(app_locs, fn app_id ->
      other_ebirds = app_to_ebirds[app_id] |> Enum.uniq() |> List.delete(ebird_loc)
      shared = if other_ebirds == [], do: "", else: " [also -> #{Enum.join(other_ebirds, ", ")}]"

      IO.puts(
        "    -> app #{app_label.(app_id)} (#{pair_counts[{ebird_loc, app_id}]} checklists)#{shared}"
      )
    end)
  end
end)

# Section 2: 1:n — one eBird loc to several app locs, none of them shared elsewhere.
IO.puts("\n1:n — one eBird location split across app locations (not linked):")

Enum.each(ambiguous, fn {ebird_loc, app_locs} ->
  app_locs = Enum.uniq(app_locs)

  if length(app_locs) > 1 and not ebird_mn?.(ebird_loc, app_locs) do
    IO.puts("  eBird #{ebird_label.(ebird_loc)}")

    Enum.each(app_locs, fn app_id ->
      IO.puts("    -> app #{app_label.(app_id)} (#{pair_counts[{ebird_loc, app_id}]} checklists)")
    end)
  end
end)

# Section 3: n:1 — one app loc to several eBird locs, none of them shared elsewhere.
IO.puts("\nn:1 — one app location split across eBird locations (not linked):")

Enum.each(app_to_ebirds, fn {app_id, ebird_locs} ->
  ebird_locs = Enum.uniq(ebird_locs)

  if length(ebird_locs) > 1 and not app_mn?.(app_id, ebird_locs) do
    IO.puts("  app #{app_label.(app_id)}")

    Enum.each(ebird_locs, fn ebird_loc ->
      IO.puts("    -> eBird #{ebird_label.(ebird_loc)} (#{pair_counts[{ebird_loc, app_id}]} checklists)")
    end)
  end
end)

linked =
  Enum.reduce(to_link, 0, fn {ebird_loc, [app_id]}, count ->
    {n, _} =
      Repo.update_all(
        from(u in UserLocation,
          where: u.user_id == ^user_id and u.ebird_loc_id == ^ebird_loc
        ),
        set: [location_id: app_id, updated_at: now]
      )

    count + n
  end)

IO.puts("\nLinked #{linked} eBird user locations (1:1) for user #{user_id}.")

# --- Name-alias pass ----------------------------------------------------------
#
# eBird locations whose name doesn't spell-match the app location's name_en, but
# which are the same place. After the checklist-based 1:1 linking above, link these
# by name: the aliased eBird name is matched against exactly one app location.
name_aliases = [
  {"Kyiv City", "Kyiv"},
  {"Kherson oblast general area", "Khersonska oblast"},
  {"Cherkas'ka Oblast'", "Cherkaska oblast"},
  {"Winnipeg--East Kildonan/Transcona", "East Kildonan/Transcona General Area"},
  {"Birds Hill PP", "Birds Hill Provincial Park"},
  {"Mitchell Lake Audubon Center (HOTE 103)", "Mitchell Lake Audubon Center"},
  {"Winnipeg--Kildonan Settlers Bridge", "Kildonan Settlers Bridge"}
]

alias_linked =
  Enum.reduce(name_aliases, 0, fn {ebird_name, app_name}, count ->
    ebird_loc =
      Repo.one(
        from u in UserLocation,
          where: u.user_id == ^user_id and u.name == ^ebird_name and is_nil(u.location_id),
          select: u.ebird_loc_id
      )

    app_ids =
      Repo.all(from l in Kjogvi.Geo.Location, where: l.name_en == ^app_name, select: l.id)

    case {ebird_loc, app_ids} do
      {nil, _} ->
        IO.puts("  alias skipped: no unlinked eBird location named #{inspect(ebird_name)}")
        count

      {_, []} ->
        IO.puts("  alias skipped: no app location named #{inspect(app_name)}")
        count

      {_, [_, _ | _]} ->
        IO.puts("  alias skipped: #{length(app_ids)} app locations named #{inspect(app_name)}")
        count

      {ebird_loc, [app_id]} ->
        {n, _} =
          Repo.update_all(
            from(u in UserLocation,
              where: u.user_id == ^user_id and u.ebird_loc_id == ^ebird_loc
            ),
            set: [location_id: app_id, updated_at: now]
          )

        count + n
    end
  end)

IO.puts("Linked #{alias_linked} eBird user locations by name alias for user #{user_id}.")
