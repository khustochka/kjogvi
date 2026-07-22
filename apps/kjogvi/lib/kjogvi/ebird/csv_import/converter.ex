defmodule Kjogvi.Ebird.CsvImport.Converter do
  @moduledoc """
  Pure conversion of eBird "Download My Data" CSV rows into the attrs maps that
  feed the `Checklist`, `Observation` and `Ebird.UserLocation` changesets.

  eBird ships one row per (`Submission ID`, species): the row carries both the
  checklist-wide fields (date, effort, location) — repeated across a submission's
  rows — and the one observation's fields. Rows are header-keyed maps as
  `CSV.decode!(headers: true)` produces them.

  No DB access, no taxon or location resolution: those are the import module's
  job. `observation_attrs/1` leaves the taxon as the row's raw `Scientific Name`
  under `:name_sci` for the caller to resolve.
  """

  # eBird protocol strings (the "Protocol" column) mapped to our effort types.
  # eBird prefixes most with "eBird - "; a handful of historical/atlas protocols
  # exist but map onto the same small set. Anything unrecognized maps to OTHER,
  # keeping the original protocol string in `effort_name` so it isn't lost.
  @effort_by_protocol %{
    "eBird - Traveling Count" => "TRAVEL",
    "eBird - Stationary Count" => "STATIONARY",
    "eBird - Exhaustive Area Count" => "AREA",
    "eBird - Casual Observation" => "INCIDENTAL",
    "Historical" => "HISTORICAL",
    "PriMig - Pri Mig Banding Protocol" => "BANDING",
    "eBird Pelagic Protocol" => "PELAGIC",
    "eBird--Nocturnal Flight Call Count" => "NOCTURNAL_FLIGHT_CALL"
  }

  @doc """
  The `Ebird.UserLocation` attrs for a row: eBird's location id, name, and the
  raw `State/Province` code and `County` name as recorded in the export. The same
  values repeat across every row of a location, so a caller upserting per
  `ebird_loc_id` can take them from any one row.
  """
  def user_location_attrs(row) do
    %{
      ebird_loc_id: blank_to_nil(row["Location ID"]),
      name: blank_to_nil(row["Location"]),
      state: blank_to_nil(row["State/Province"]),
      county: blank_to_nil(row["County"]),
      lat: blank_to_nil(row["Latitude"]),
      lon: blank_to_nil(row["Longitude"])
    }
  end

  @doc """
  The checklist-wide attrs for a submission, taken from one of its rows (all
  carry the same values). `location_id` and the observations are added by the
  caller; `ebird_id` is the eBird `Submission ID`.

  Returns `{:ok, attrs}`, or `{:error, :missing_submission_id}` when the row has
  no `Submission ID` — a truly invalid row (a malformed export), distinct from a
  changeset failure downstream, which would signal a bug in our own mapping.
  """
  def checklist_attrs(row) do
    case blank_to_nil(row["Submission ID"]) do
      nil -> {:error, :missing_submission_id}
      ebird_id -> {:ok, checklist_attrs(row, ebird_id)}
    end
  end

  defp checklist_attrs(row, ebird_id) do
    {effort_type, effort_name} = effort(row["Protocol"])

    %{
      ebird_id: ebird_id,
      observ_date: parse_date(row["Date"]),
      start_time: parse_time(row["Time"]),
      effort_type: effort_type,
      effort_name: effort_name,
      duration_minutes: parse_integer(row["Duration (Min)"]),
      distance_kms: parse_float(row["Distance Traveled (km)"]),
      area_acres: hectares_to_acres(parse_float(row["Area Covered (ha)"])),
      observers: parse_integer(row["Number of Observers"]) |> to_observers_string(),
      ebird_complete: parse_complete(row["All Obs Reported"]),
      notes: blank_to_nil(row["Checklist Comments"]),
      import_source: :ebird
    }
  end

  @doc """
  One observation's attrs. The taxon is not resolved here: the raw
  `Scientific Name` is returned under `:name_sci` for the caller to look up and
  turn into a `taxon_key`.
  """
  def observation_attrs(row) do
    %{
      name_sci: blank_to_nil(row["Scientific Name"]),
      quantity: parse_quantity(row["Count"]),
      breeding_code: breeding_code(row["Breeding Code"]),
      notes: blank_to_nil(row["Observation Details"]),
      ml_catalog_numbers: parse_ml_catalog_numbers(row["ML Catalog Numbers"]),
      import_source: :ebird
    }
  end

  @doc """
  The bare code from an eBird breeding-code cell, which is stored as
  `"<code> <text>"` (e.g. `"CF Carrying Food"`). Returns just `"CF"`, or nil for
  a blank cell.
  """
  def breeding_code(nil), do: nil
  def breeding_code(""), do: nil

  def breeding_code(value) do
    value |> String.trim() |> String.split(" ", parts: 2) |> List.first()
  end

  # eBird records "X" for "present, uncounted"; `Observation.quantity` is a free
  # string, so both "X" and a number pass through verbatim.
  defp parse_quantity(value), do: blank_to_nil(value)

  # A known protocol maps to its effort type (no `effort_name`); an unrecognized
  # one becomes OTHER carrying the original protocol string as `effort_name`. A
  # blank protocol is neither and stays untyped.
  defp effort(protocol) do
    case blank_to_nil(protocol) do
      nil -> {nil, nil}
      trimmed -> effort(trimmed, Map.get(@effort_by_protocol, trimmed))
    end
  end

  defp effort(_protocol, effort_type) when is_binary(effort_type), do: {effort_type, nil}
  defp effort(protocol, nil), do: {"OTHER", protocol}

  # "All Obs Reported" is 1 (complete checklist) or 0; anything else is unknown.
  defp parse_complete("1"), do: true
  defp parse_complete("0"), do: false
  defp parse_complete(_), do: nil

  # ML catalog numbers arrive as a space-separated list in one cell.
  defp parse_ml_catalog_numbers(nil), do: []
  defp parse_ml_catalog_numbers(""), do: []
  defp parse_ml_catalog_numbers(value), do: String.split(value, ~r/\s+/, trim: true)

  # eBird records observer *count*; `Checklist.observers` is a free-text field, so
  # keep the count as its string form (nil when unknown).
  defp to_observers_string(nil), do: nil
  defp to_observers_string(count), do: Integer.to_string(count)

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil

  defp parse_date(value) do
    case Date.from_iso8601(String.trim(value)) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end

  # eBird times are 12-hour with an AM/PM marker, e.g. "01:00 PM"; blank for
  # checklists without a start time.
  defp parse_time(nil), do: nil
  defp parse_time(""), do: nil

  defp parse_time(value) do
    case Datix.Time.parse(String.trim(value), "%I:%M %p") do
      {:ok, time} -> time
      {:error, _} -> nil
    end
  end

  # 1 ha = 2.47105 acres. `Checklist.area_acres` stores acres; eBird exports
  # hectares.
  defp hectares_to_acres(nil), do: nil
  defp hectares_to_acres(hectares), do: hectares * 2.47105

  defp parse_integer(nil), do: nil
  defp parse_integer(""), do: nil

  defp parse_integer(value) do
    case Integer.parse(String.trim(value)) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp parse_float(nil), do: nil
  defp parse_float(""), do: nil

  # eBird writes fractional values without a leading zero (`.729`, `-.5`), which
  # `Float.parse` rejects; restore the zero before parsing.
  defp parse_float(value) do
    case Float.parse(leading_zero(String.trim(value))) do
      {float, _} -> float
      :error -> nil
    end
  end

  defp leading_zero("." <> _ = value), do: "0" <> value
  defp leading_zero("-." <> rest), do: "-0." <> rest
  defp leading_zero(value), do: value

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
