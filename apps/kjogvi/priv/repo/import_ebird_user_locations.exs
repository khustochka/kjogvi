# Extracts distinct eBird locations from a "Download My Data" CSV export and
# inserts them into ebird_user_locations for a given user.
#
# Usage:
#   mix run apps/kjogvi/priv/repo/import_ebird_user_locations.exs "/path/to/MyEBirdData.csv" [user_id]

alias Kjogvi.Repo
alias Kjogvi.Ebird.UserLocation

[path | rest] = System.argv()
user_id = rest |> List.first("1") |> String.to_integer()

now = DateTime.utc_now()

rows =
  path
  |> File.stream!()
  |> CSV.decode!(headers: true)
  |> Enum.reduce(%{}, fn row, acc ->
    loc_id = row["Location ID"]
    blank = &if(&1 in [nil, ""], do: nil, else: &1)
    decimal = &(blank.(&1) && Decimal.new(&1))

    Map.put_new(acc, loc_id, %{
      ebird_loc_id: loc_id,
      name: row["Location"],
      state: blank.(row["State/Province"]),
      county: blank.(row["County"]),
      lat: decimal.(row["Latitude"]),
      lon: decimal.(row["Longitude"]),
      user_id: user_id,
      inserted_at: now,
      updated_at: now
    })
  end)
  |> Map.values()

{count, _} =
  Repo.insert_all(UserLocation, rows,
    on_conflict: :nothing,
    conflict_target: [:user_id, :ebird_loc_id]
  )

IO.puts("Inserted #{count} of #{length(rows)} distinct eBird locations for user #{user_id}.")
