defmodule Kjogvi.Imports.ImportError do
  @moduledoc """
  Rows an import run could not import, kept verbatim for admin review and a
  later re-run.

  One record per failed submission (or per submission's dropped rows) of a
  `Kjogvi.Imports.ImportLog` run: `rows` holds the raw source rows as parsed
  from the file (string-keyed CSV maps), so the exact failing input survives
  the run. Categories mirror the run summary's counts:

    * `:invalid` — malformed submission (e.g. no `Submission ID`)
    * `:unmapped` — the checklist's location has no mapped common location
    * `:failed` — the checklist changeset was rejected; `error` has details
    * `:unresolved_taxa` — rows dropped from an otherwise imported checklist
      because their scientific names aren't in the user's taxonomy book

  Runs that fail wholesale don't produce these records — the retained upload
  (`ImportLog.upload_key`) is the ground truth there.
  """

  use Kjogvi.Schema

  alias Kjogvi.Imports.ImportLog

  @categories [:invalid, :unmapped, :failed, :unresolved_taxa]

  schema "import_errors" do
    field :category, Ecto.Enum, values: @categories
    field :submission_id, :string
    field :rows, {:array, :map}, default: []
    field :error, :string

    belongs_to(:import_log, ImportLog)

    timestamps()
  end
end
