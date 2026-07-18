defmodule Kjogvi.Jobs.Geo.Dump do
  @moduledoc """
  Dumps a geo dataset to its snapshot (`Kjogvi.Geo.Dump`) as an exclusive
  job: one run per dataset at a time.
  """

  use Kjogvi.Jobs.Runtime.ExclusiveWorker, queue: :geo, unique_keys: [:dataset]

  alias Kjogvi.Jobs.Geo.Dataset

  @impl Kjogvi.Jobs.Runtime.ExclusiveWorker
  def pubsub_key(%Oban.Job{args: %{"dataset" => dataset}}) do
    {:geo_dump, Dataset.key_part(dataset)}
  end

  @impl Kjogvi.Jobs.Runtime.ExclusiveWorker
  def start_message(%Oban.Job{args: %{"dataset" => dataset}}) do
    "Dumping #{Dataset.label(dataset)}..."
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"dataset" => dataset}}) do
    Kjogvi.Geo.Dump.run(Dataset.parse(dataset))
  end
end
