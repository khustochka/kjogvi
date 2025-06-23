alias Kjogvi.{Repo, Geo.Location}
import Ecto.Query

# Read the locations dump
{:ok, data} = File.read!("locations_dump.json") |> Jason.decode()

# Get columns and rows
columns = data["columns"]
rows = data["rows"]

IO.puts("Importing #{length(rows)} locations...")

# Create a function to map row data to location attributes
map_location_data = fn row, columns ->
  row_map = Enum.zip(columns, row) |> Enum.into(%{})

  %{
    id: row_map["id"],
    slug: row_map["slug"],
    name_en: row_map["name_en"],
    location_type: row_map["loc_type"],
    ancestry:
      if(row_map["ancestry"],
        do: String.split(row_map["ancestry"], "/") |> Enum.map(&String.to_integer/1),
        else: []
      ),
    iso_code: row_map["iso_code"],
    is_private: row_map["private_loc"] || false,
    is_patch: row_map["patch"] || false,
    is_5mr: row_map["five_mile_radius"] || false,
    lat: if(row_map["lat"], do: Decimal.new(to_string(row_map["lat"])), else: nil),
    lon: if(row_map["lon"], do: Decimal.new(to_string(row_map["lon"])), else: nil),
    public_index: row_map["public_index"],
    cached_country_id: row_map["cached_country_id"],
    cached_parent_id: row_map["cached_parent_id"],
    cached_city_id: row_map["cached_city_id"],
    cached_subdivision_id: row_map["cached_subdivision_id"],
    inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
    updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
  }
end

# Clear existing locations
Repo.delete_all(Location)
IO.puts("Cleared existing locations")

# Reset the sequence to start from 1
Repo.query!("ALTER SEQUENCE locations_id_seq RESTART WITH 1")

# Import locations in batches to handle large dataset
chunk_size = 100

rows
|> Enum.chunk_every(chunk_size)
|> Enum.with_index()
|> Enum.each(fn {chunk, index} ->
  IO.puts("Processing batch #{index + 1}/#{ceil(length(rows) / chunk_size)}...")

  location_data = Enum.map(chunk, &map_location_data.(&1, columns))

  # Insert batch
  {count, _} =
    Repo.insert_all(Location, location_data,
      on_conflict: :replace_all,
      conflict_target: :id
    )

  IO.puts("Inserted #{count} locations")
end)

# Update the sequence to continue from the highest ID
max_id = Repo.one(from(l in Location, select: max(l.id))) || 0
Repo.query!("ALTER SEQUENCE locations_id_seq RESTART WITH #{max_id + 1}")

total_count = Repo.aggregate(Location, :count)
IO.puts("Import complete! Total locations: #{total_count}")

# Show some sample data
sample_locations = Repo.all(from(l in Location, limit: 5, order_by: l.id))
IO.puts("\nSample locations:")

Enum.each(sample_locations, fn loc ->
  IO.puts("  #{loc.id}: #{loc.name_en} (#{loc.location_type}) - #{loc.slug}")
end)
