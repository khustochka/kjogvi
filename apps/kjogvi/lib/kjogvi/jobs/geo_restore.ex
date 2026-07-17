defmodule Kjogvi.Jobs.GeoRestore do
  @moduledoc """
  Restores a geo dataset from its snapshot (`Kjogvi.Geo.Restore`) as an
  exclusive job: one run per dataset at a time.
  """

  use Kjogvi.Jobs.ExclusiveWorker, queue: :geo, unique_keys: [:dataset]

  alias Kjogvi.Jobs.GeoDataset

  @impl Kjogvi.Jobs.ExclusiveWorker
  def pubsub_key(%Oban.Job{args: %{"dataset" => dataset}}) do
    {:geo_restore, GeoDataset.key_part(dataset)}
  end

  @impl Kjogvi.Jobs.ExclusiveWorker
  def start_message(%Oban.Job{args: %{"dataset" => dataset}}) do
    "Restoring #{GeoDataset.label(dataset)}..."
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"dataset" => dataset}}) do
    Kjogvi.Geo.Restore.run(GeoDataset.parse(dataset))
  end
end
