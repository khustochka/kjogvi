defmodule Kjogvi.Ebird.Import do
  @moduledoc """
  Imports observations from an eBird "Download My Data" export.

  eBird ships the export as a `.zip` holding a single `MyEBirdData.csv`. The
  import job (`Kjogvi.Jobs.Ebird.Import`) unpacks the zip to a scratch dir and
  hands the CSV path here.

  Placeholder: for now this only opens the CSV and counts its data rows — the
  row-to-`Checklist`/`Observation` mapping, taxon resolution (Ornithologue)
  and location matching are a follow-up.
  """

  require Logger

  @doc """
  Runs the import against the CSV at `csv_path` for `user`.

  Returns `{:ok, %{row_count: n}}`. `opts` carries a `:broadcast_key` (the
  Oban job) so the real import can report progress on the job row and its
  PubSub topic — unused by the placeholder.
  """
  def run(user, csv_path, _opts \\ []) do
    row_count = count_data_rows(csv_path)

    Logger.info("eBird import (placeholder): #{row_count} rows for user #{user.id}")

    {:ok, %{row_count: row_count}}
  end

  # Streams the file so a large export is never fully loaded. The header line
  # is dropped; the real parser will use NimbleCSV to handle quoted fields.
  defp count_data_rows(csv_path) do
    csv_path
    |> File.stream!()
    |> Stream.drop(1)
    |> Enum.count()
  end
end
