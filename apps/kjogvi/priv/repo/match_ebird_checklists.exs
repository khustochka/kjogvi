# Matches a user's app checklists that have no `ebird_id` yet against eBird
# submissions from the "Download My Data" CSV, so the eBird submission id can be
# attached later.
#
# A visit's natural key is date + start time; the ideal match adds location. For
# each unmatched app checklist we find available eBird submissions sharing its date
# and start time (start time is part of the key — nil matches only nil), then:
#
#   - matched     : one such submission, at a location linked to this app location.
#   - by_location : several share the date/time, and the linked location picks one.
#   - by_taxa     : location can't decide (unlinked, or none at a linked location),
#                   but taxa count uniquely separates them on both sides.
#   - ambiguous   : still can't tell them apart -> left unmatched, not in the CSV.
#   - none        : no available eBird submission at that date+time.
#
# Only eBird submissions not already attached to some checklist are considered.
# The script writes nothing to the DB; it emits a CSV report for review.
#
# Usage:
#   mix run apps/kjogvi/priv/repo/match_ebird_checklists.exs "/path/to/MyEBirdData.csv" [user_id] [out.csv]

import Ecto.Query

alias Kjogvi.Repo
alias Kjogvi.Birding.Checklist
alias Kjogvi.Ebird.UserLocation

Logger.configure(level: :warning)

[path | rest] = System.argv()
user_id = rest |> Enum.at(0, "1") |> String.to_integer()
out_path = Enum.at(rest, 1, "ebird_matches.csv")

# --- eBird side: submissions from the CSV, aggregated per submission ----------

# eBird submission ids already attached to a checklist are off the table.
taken_ebird_ids =
  Repo.all(
    from c in Checklist,
      where: c.user_id == ^user_id and not is_nil(c.ebird_id),
      select: c.ebird_id
  )
  |> MapSet.new()

# eBird's Time column is "hh:mm AM/PM" (or blank); parse to a Time for comparison.
parse_ebird_time = fn
  time when time in [nil, ""] ->
    nil

  time ->
    case Regex.run(~r/^(\d{1,2}):(\d{2}) (AM|PM)$/, time) do
      [_, hh, mm, ampm] ->
        hh = String.to_integer(hh)

        hour =
          case {ampm, hh} do
            {"AM", 12} -> 0
            {"AM", h} -> h
            {"PM", 12} -> 12
            {"PM", h} -> h + 12
          end

        Time.new!(hour, String.to_integer(mm), 0)

      _ ->
        nil
    end
end

# submission_id -> %{loc_id, date, species: MapSet of scientific names, name, ...}
# eBird has one CSV row per (submission, taxon); fold rows into per-submission info.
ebird =
  path
  |> File.stream!()
  |> CSV.decode!(headers: true)
  |> Enum.reduce(%{}, fn row, acc ->
    sub = row["Submission ID"]

    if MapSet.member?(taken_ebird_ids, sub) do
      acc
    else
      Map.update(
        acc,
        sub,
        %{
          loc_id: row["Location ID"],
          loc_name: row["Location"],
          date: row["Date"],
          time: parse_ebird_time.(row["Time"]),
          protocol: row["Protocol"],
          duration: row["Duration (Min)"],
          species: MapSet.new([row["Scientific Name"]])
        },
        fn info -> %{info | species: MapSet.put(info.species, row["Scientific Name"])} end
      )
    end
  end)

# app_location_id -> [ebird_loc_id, ...] it is linked to
app_loc_to_ebird_locs =
  Repo.all(
    from u in UserLocation,
      where: u.user_id == ^user_id and not is_nil(u.location_id),
      select: {u.location_id, u.ebird_loc_id}
  )
  |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

# The set of eBird loc ids that map to a given app location.
ebird_locs_for_app_loc =
  Map.new(app_loc_to_ebird_locs, fn {app_loc, ebird_locs} -> {app_loc, MapSet.new(ebird_locs)} end)

# Group eBird submissions by {date, start_time} — the natural key of a visit. Start
# time is a real part of the key: nil (untimed) only matches nil.
ebird_by_date_time =
  Enum.group_by(ebird, fn {_sub, info} -> {info.date, info.time} end, fn {sub, info} ->
    {sub, info}
  end)

# --- App side: all of the user's checklists not yet linked to eBird ------------

# Species count per checklist is a distinct-taxon count (not the "countable species"
# metric): eBird's per-submission taxon rows line up with our observations' taxa.
app_checklists =
  Repo.all(
    from c in Checklist,
      left_join: obs in assoc(c, :observations),
      where: c.user_id == ^user_id and is_nil(c.ebird_id) and not is_nil(c.location_id),
      group_by: c.id,
      select: %{
        id: c.id,
        location_id: c.location_id,
        date: c.observ_date,
        start_time: c.start_time,
        effort_type: c.effort_type,
        duration: c.duration_minutes,
        taxa_count: count(fragment("DISTINCT ?", obs.taxon_key))
      }
  )

# app location id -> name, for the report
app_names =
  Repo.all(from l in Kjogvi.Geo.Location, select: {l.id, l.name_en})
  |> Map.new()

# --- Matching -----------------------------------------------------------------
#
# The ideal key is (date, start_time, location). Date + start time is a strong
# natural key for a visit; when several eBird subs share it, location decides. When
# the location link can't decide (the app location isn't linked to any eBird loc),
# a matching eBird location *name* decides; failing that, taxa count.
#
# Start time is a real part of the key: nil (untimed) matches only nil.

# eBird loc ids linked to a given app location (empty set if unlinked).
linked_ebird_locs = fn app_loc -> Map.get(ebird_locs_for_app_loc, app_loc, MapSet.new()) end

norm_name = fn name -> name |> to_string() |> String.trim() |> String.downcase() end

# eBird location names that don't spell-match the app's own name. Keys and values
# are pre-normalized (trimmed, lowercased); the eBird name is rewritten to the app
# name before the by-name comparison.
name_aliases =
  Map.new(
    [
      {"Kyiv City", "Kyiv"},
      {"Kherson oblast general area", "Khersonska oblast"},
      {"Cherkas'ka Oblast'", "Cherkaska oblast"},
      {"Winnipeg--East Kildonan/Transcona", "East Kildonan/Transcona General Area"},
      {"Birds Hill PP", "Birds Hill Provincial Park"},
      {"Mitchell Lake Audubon Center (HOTE 103)", "Mitchell Lake Audubon Center"},
      {"Winnipeg--Kildonan Settlers Bridge", "Kildonan Settlers Bridge"}
    ],
    fn {ebird, app} -> {norm_name.(ebird), norm_name.(app)} end
  )

# Normalized eBird location name, with aliases folded onto the app-side spelling.
norm_ebird_name = fn name ->
  normed = norm_name.(name)
  Map.get(name_aliases, normed, normed)
end

# All available eBird subs sharing this checklist's date + start time.
candidates_for = fn app ->
  Map.get(ebird_by_date_time, {Date.to_iso8601(app.date), app.start_time}, [])
end

app_key = fn app -> {app.date, app.start_time} end

# Classify one app checklist against the still-available submissions and the still-
# unresolved app checklists sharing its (date, start_time) key. `available` is a
# MapSet of submission ids not yet claimed by a confident match; `unresolved_peers`
# is the list of app checklists in this same key cell that are also still open (used
# for the "unique on both sides" test). Returns {method, sub, info} | :ambiguous |
# :none. Only :none once no candidates remain at all; :ambiguous while some remain
# but nothing separates this checklist from its peers this round.
classify = fn app, available, unresolved_peers ->
  candidates =
    candidates_for.(app) |> Enum.filter(fn {sub, _info} -> MapSet.member?(available, sub) end)

  all_candidates = candidates_for.(app)
  ebird_locs = linked_ebird_locs.(app.location_id)
  app_name = norm_name.(app_names[app.location_id])

  at_linked_loc =
    Enum.filter(candidates, fn {_sub, info} -> MapSet.member?(ebird_locs, info.loc_id) end)

  by_name = Enum.filter(candidates, fn {_sub, info} -> norm_ebird_name.(info.loc_name) == app_name end)

  # Unique on the app side, among peers still open in this key cell.
  unique_app_name? =
    Enum.count(unresolved_peers, &(norm_name.(app_names[&1.location_id]) == app_name)) == 1

  unique_app_taxa? = Enum.count(unresolved_peers, &(&1.taxa_count == app.taxa_count)) == 1

  cond do
    # No eBird submission ever existed at this date+time. (Distinct from all its
    # subs being claimed by others, which leaves it :ambiguous, not :none.)
    all_candidates == [] ->
      :none

    candidates == [] ->
      :ambiguous

    match?([_], at_linked_loc) and length(candidates) == 1 ->
      [{sub, info}] = at_linked_loc
      {"matched", sub, info}

    match?([_], at_linked_loc) ->
      [{sub, info}] = at_linked_loc
      {"by_location", sub, info}

    match?([_], by_name) and unique_app_name? ->
      [{sub, info}] = by_name
      {"by_name", sub, info}

    true ->
      matching =
        Enum.filter(candidates, fn {_sub, info} -> MapSet.size(info.species) == app.taxa_count end)

      case matching do
        [{sub, info}] when unique_app_taxa? -> {"by_taxa", sub, info}
        _ -> :ambiguous
      end
  end
end

# Greedy fixpoint: each round, classify every still-open app checklist against the
# submissions still available and its still-open peers; commit the confident matches
# (they consume their submission); repeat until a round produces no new match. A
# confident match earlier can remove a competing candidate and let a neighbour
# resolve next round (e.g. Sadove claims its sub, so Kherson stops seeing it).
resolve = fn ->
  initial_available =
    ebird_by_date_time |> Map.values() |> List.flatten() |> Enum.map(&elem(&1, 0)) |> MapSet.new()

  Enum.reduce_while(Stream.cycle([:round]), {app_checklists, [], initial_available}, fn _, {open, done, available} ->
    peers_by_key = Enum.group_by(open, app_key)

    round_matches =
      for app <- open,
          {method, sub, info} <- [classify.(app, available, peers_by_key[app_key.(app)])] |> Enum.filter(&is_tuple/1),
          do: {app, method, sub, info}

    # If two open checklists both want the same submission this round, neither is
    # safe to commit — defer them so a later round (with fewer competitors) decides.
    contested =
      round_matches
      |> Enum.frequencies_by(fn {_app, _m, sub, _info} -> sub end)
      |> Enum.filter(fn {_sub, n} -> n > 1 end)
      |> MapSet.new(fn {sub, _n} -> sub end)

    committed = Enum.reject(round_matches, fn {_a, _m, sub, _i} -> MapSet.member?(contested, sub) end)

    if committed == [] do
      {:halt, {open, done, available}}
    else
      claimed = MapSet.new(committed, fn {_app, _m, sub, _info} -> sub end)
      matched_app_ids = MapSet.new(committed, fn {app, _m, _s, _i} -> app.id end)

      {:cont,
       {
         Enum.reject(open, &MapSet.member?(matched_app_ids, &1.id)),
         done ++ committed,
         MapSet.difference(available, claimed)
       }}
    end
  end)
end

{unresolved, matches, available} = resolve.()

# Still-competing eBird subs for an unresolved app checklist: same date+time and not
# yet claimed by a confident match (a claimed sub is no longer a real competitor).
open_candidates_for = fn app ->
  candidates_for.(app) |> Enum.filter(fn {sub, _info} -> MapSet.member?(available, sub) end)
end

# none: no eBird submission ever existed at that date+time. Everything else left
# unresolved is a genuine ambiguity (tied with peers, or its subs went to others).
none = for app <- unresolved, candidates_for.(app) == [], do: app
ambiguous = for app <- unresolved, candidates_for.(app) != [], do: app

# --- CSV report ---------------------------------------------------------------

csv_escape = fn
  nil -> ""
  val -> ~s("#{String.replace(to_string(val), "\"", "\"\"")}")
end

header =
  ~w(app_checklist_id ebird_submission_id method date app_location app_taxa_count app_effort_type app_duration ebird_location ebird_species_count ebird_protocol ebird_duration)

lines =
  Enum.map(matches, fn {app, method, sub, info} ->
    [
      app.id,
      sub,
      method,
      Date.to_iso8601(app.date),
      app_names[app.location_id],
      app.taxa_count,
      app.effort_type,
      app.duration,
      info.loc_name,
      MapSet.size(info.species),
      info.protocol,
      info.duration
    ]
    |> Enum.map(csv_escape)
    |> Enum.join(",")
  end)

File.write!(out_path, [Enum.join(header, ","), "\n", Enum.intersperse(lines, "\n"), "\n"])

count_method = fn m -> Enum.count(matches, fn {_, meth, _, _} -> meth == m end) end

fmt_time = fn
  nil -> "--:--"
  %Time{} = t -> Calendar.strftime(t, "%H:%M")
end

IO.puts("Match by date + start time (+ location, taxa count) for user #{user_id}:")
IO.puts("  unmatched app checklists: #{length(app_checklists)}")

IO.puts(
  "  matched: #{length(matches)}  (#{count_method.("matched")} date+time+location, #{count_method.("by_location")} by linked location, #{count_method.("by_name")} by location name, #{count_method.("by_taxa")} by taxa count)"
)

IO.puts("  ambiguous (same date+time, taxa count didn't separate them): #{length(ambiguous)}")
IO.puts("  no eBird submission at that date+time:                        #{length(none)}")
IO.puts("\nWrote #{length(matches)} matches to #{out_path}")

IO.puts("\nNo eBird submission at that date+time (id, location, date):")

none
|> Enum.sort_by(& &1.date, Date)
|> Enum.each(fn app ->
  IO.puts("  #{app.id}\t#{app_names[app.location_id]}\t#{Date.to_iso8601(app.date)}")
end)

# --- HTML report for ambiguous cases ------------------------------------------

html_out = String.replace_suffix(out_path, ".csv", "") <> "_ambiguous.html"

h = fn val ->
  val
  |> to_string()
  |> String.replace("&", "&amp;")
  |> String.replace("<", "&lt;")
  |> String.replace(">", "&gt;")
  |> String.replace("\"", "&quot;")
end

card_url = fn id -> "https://birdwatch.org.ua/cards/#{id}/edit" end
ebird_url = fn sub -> "https://ebird.org/checklist/#{sub}" end
date_url = fn date -> "https://birdwatch.org.ua/cards?q%5Btaxon_id%5D=&q%5Bobserv_date%5D=#{date}" end

# One section per date: ambiguous app checklists (with candidates), then app
# checklists that had no eBird submission at all on that date+loc.
ambiguous_by_date = Enum.group_by(ambiguous, &Date.to_iso8601(&1.date))
none_by_date = Enum.group_by(none, &Date.to_iso8601(&1.date))
all_dates = (Map.keys(ambiguous_by_date) ++ Map.keys(none_by_date)) |> Enum.uniq() |> Enum.sort()

sections =
  Enum.map(all_dates, fn date ->
    amb = Map.get(ambiguous_by_date, date, [])
    non = Map.get(none_by_date, date, [])

    amb_html =
      Enum.map(amb, fn app ->
        cands =
          open_candidates_for.(app)
          |> Enum.map(fn {sub, info} ->
            """
                <li><a href="#{ebird_url.(sub)}" target="_blank" rel="noopener">#{h.(sub)}</a>
                — #{h.(info.loc_name)} · #{fmt_time.(info.time)} · #{MapSet.size(info.species)} species</li>
            """
          end)

        """
          <div class="app">
            <a href="#{card_url.(app.id)}" target="_blank" rel="noopener">card #{app.id}</a>
            — #{h.(app_names[app.location_id])} · #{fmt_time.(app.start_time)} · #{app.taxa_count} taxa
            <ul class="ebird">
        #{cands}
            </ul>
          </div>
        """
      end)

    non_html =
      case non do
        [] ->
          ""

        list ->
          items =
            Enum.map(list, fn app ->
              """
                  <li><a href="#{card_url.(app.id)}" target="_blank" rel="noopener">card #{app.id}</a>
                  — #{h.(app_names[app.location_id])}</li>
              """
            end)

          """
            <div class="none">
              <p class="none-label">No eBird submission at that location on this date:</p>
              <ul>
          #{items}
              </ul>
            </div>
          """
      end

    """
      <section>
        <h2><a href="#{date_url.(date)}" target="_blank" rel="noopener">#{h.(date)}</a></h2>
    #{amb_html}
    #{non_html}
      </section>
    """
  end)

# --- location pairs to review (by_name, by_taxa) ------------------------------
#
# Matches made by location name or by taxa count imply an (app location -> eBird
# location) pairing that wasn't confirmed by an existing location link. Lay them out
# as a two-column name comparison so mismatches are easy to spot; ids, method, and
# checklist count sit below each name. Flag any pair that isn't 1:1 (an app location
# paired with several eBird locations, or vice versa).
review_pairs =
  for {app, method, _sub, info} <- matches, method in ["by_name", "by_taxa"] do
    {{app.location_id, app_names[app.location_id]}, {info.loc_id, info.loc_name}, method}
  end

# Distinct pair -> {checklist count, set of methods that produced it}.
pair_stats =
  Enum.reduce(review_pairs, %{}, fn {app, ebird, method}, acc ->
    Map.update(acc, {app, ebird}, {1, MapSet.new([method])}, fn {n, ms} ->
      {n + 1, MapSet.put(ms, method)}
    end)
  end)

pair_app_to_ebird = Enum.group_by(Map.keys(pair_stats), fn {app, _e} -> app end)
pair_ebird_to_app = Enum.group_by(Map.keys(pair_stats), fn {_a, ebird} -> ebird end)

pair_not_1to1? = fn {app, ebird} ->
  length(Enum.uniq_by(pair_app_to_ebird[app], fn {_a, e} -> e end)) > 1 or
    length(Enum.uniq_by(pair_ebird_to_app[ebird], fn {a, _e} -> a end)) > 1
end

pair_rows_html =
  pair_stats
  |> Enum.sort_by(fn {{{_aid, aname}, _e}, _stats} -> String.downcase(to_string(aname)) end)
  |> Enum.map(fn {{{app_id, app_name}, {ebird_id, ebird_name}} = pair, {n, methods}} ->
    row_class = if pair_not_1to1?.(pair), do: ~s( class="warn"), else: ""
    method_txt = methods |> Enum.sort() |> Enum.join(", ")

    """
        <tr#{row_class}>
          <td class="name">#{h.(app_name)}<span class="meta">app #{app_id}</span></td>
          <td class="name">#{h.(ebird_name)}<span class="meta">#{h.(ebird_id)}</span></td>
          <td class="meta-cell">#{method_txt}<span class="meta">#{n} checklists</span></td>
        </tr>
    """
  end)

not_1to1_count = Enum.count(Map.keys(pair_stats), pair_not_1to1?)

taxa_section =
  if pair_stats == %{} do
    ""
  else
    """
    <section>
      <h2>Location pairs to review (matched by name or taxa count)</h2>
      <p>#{map_size(pair_stats)} distinct pairs, #{not_1to1_count} not 1:1 (highlighted).</p>
      <table class="pairs">
        <thead>
          <tr><th>App location</th><th>eBird location</th><th>via</th></tr>
        </thead>
        <tbody>
    #{pair_rows_html}
        </tbody>
      </table>
    </section>
    """
  end

html = """
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>eBird ambiguous matches — user #{user_id}</title>
<style>
  body { font-family: system-ui, sans-serif; max-width: 60rem; margin: 2rem auto; padding: 0 1rem; line-height: 1.5; }
  h1 { font-size: 1.4rem; }
  section { border-top: 2px solid #ccc; padding-top: 0.5rem; margin-top: 1.5rem; }
  h2 { font-size: 1.15rem; margin: 0.5rem 0; }
  .app { margin: 0.75rem 0; padding-left: 0.5rem; border-left: 3px solid #6aa84f; }
  ul.ebird { margin: 0.25rem 0 0.5rem 0; }
  table.pairs { border-collapse: collapse; width: 100%; }
  table.pairs th, table.pairs td { border: 1px solid #ddd; padding: 0.35rem 0.6rem; text-align: left; vertical-align: top; }
  table.pairs th { background: #f4f4f4; font-size: 0.85rem; }
  table.pairs td.name { font-weight: 600; }
  table.pairs .meta, table.pairs .meta-cell { display: block; font-weight: 400; font-size: 0.8rem; color: #666; }
  table.pairs tr.warn td { background: #fbe9e9; }
  table.pairs tr.warn td.name { color: #a33; }
  .warn { color: #a33; font-weight: 600; }
  .none { margin-top: 1rem; }
  .none-label { font-style: italic; color: #a33; margin-bottom: 0.25rem; }
  a { color: #1155cc; }
</style>
</head>
<body>
<h1>eBird ambiguous matches — user #{user_id}</h1>
<p>#{length(ambiguous)} ambiguous app checklists, #{length(none)} with no eBird submission at their location+date, across #{length(all_dates)} dates.</p>
#{taxa_section}
#{sections}
</body>
</html>
"""

File.write!(html_out, html)
IO.puts("\nWrote HTML report to #{html_out}")

IO.puts(
  "  location pairs to review (by name/taxa): #{map_size(pair_stats)} distinct, #{not_1to1_count} not 1:1 (see HTML)."
)
