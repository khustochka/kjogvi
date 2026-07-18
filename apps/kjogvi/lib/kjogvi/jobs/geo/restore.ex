defmodule Kjogvi.Jobs.Geo.Restore do
  @moduledoc """
  Restores a geo dataset from its snapshot (`Kjogvi.Geo.Restore`) as an
  exclusive job: one run per dataset at a time.
  """

  use Kjogvi.Jobs.Runtime.ExclusiveWorker, queue: :geo, unique_keys: [:dataset]

  alias Kjogvi.Jobs.Geo.Dataset

  @impl Kjogvi.Jobs.Runtime.ExclusiveWorker
  def pubsub_key(%Oban.Job{args: %{"dataset" => dataset}}) do
    {:geo_restore, Dataset.key_part(dataset)}
  end

  @impl Kjogvi.Jobs.Runtime.ExclusiveWorker
  def start_message(%Oban.Job{args: %{"dataset" => dataset}}) do
    "Restoring #{Dataset.label(dataset)}..."
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"dataset" => dataset}}) do
    Kjogvi.Geo.Restore.run(Dataset.parse(dataset))
  end
end
