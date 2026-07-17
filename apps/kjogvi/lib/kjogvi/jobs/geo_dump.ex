defmodule Kjogvi.Jobs.GeoDump do
  @moduledoc """
  Dumps a geo dataset to its snapshot (`Kjogvi.Geo.Dump`) as an exclusive
  job: one run per dataset at a time.
  """

  use Kjogvi.Jobs.ExclusiveWorker, queue: :geo, unique_keys: [:dataset]

  alias Kjogvi.Jobs.GeoDataset

  @impl Kjogvi.Jobs.ExclusiveWorker
  def pubsub_key(%Oban.Job{args: %{"dataset" => dataset}}) do
    {:geo_dump, GeoDataset.key_part(dataset)}
  end

  @impl Kjogvi.Jobs.ExclusiveWorker
  def start_message(%Oban.Job{args: %{"dataset" => dataset}}) do
    "Dumping #{GeoDataset.label(dataset)}..."
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"dataset" => dataset}}) do
    Kjogvi.Geo.Dump.run(GeoDataset.parse(dataset))
  end
end
