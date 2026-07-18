defmodule Kjogvi.Telemetry.LegacyBroadcast do
  @moduledoc false

  def setup do
    :telemetry.attach_many(
      __MODULE__,
      [
        [:kjogvi, :legacy, :import, :prepare, :start],
        [:kjogvi, :legacy, :import, :locations, :start],
        [:kjogvi, :legacy, :import, :locations, :progress],
        [:kjogvi, :legacy, :import, :locations, :after_import, :start],
        [:kjogvi, :legacy, :import, :checklists, :start],
        [:kjogvi, :legacy, :import, :checklists, :progress],
        [:kjogvi, :legacy, :import, :observations, :start],
        [:kjogvi, :legacy, :import, :observations, :progress],
        [:kjogvi, :legacy, :import, :observations, :after_import, :start],
        [:kjogvi, :legacy, :import, :images, :start],
        [:kjogvi, :legacy, :import, :images, :progress]
      ],
      &__MODULE__.handle_event/4,
      nil
    )
  end

  def handle_event(
        [:kjogvi, :legacy, :import, :prepare, :start] = _event,
        _measurements,
        %{broadcast_key: broadcast_key} = _metadata,
        _config
      ) do
    broadcast(
      broadcast_key,
      %{message: "Preparing legacy import..."}
    )
  end

  def handle_event(
        [:kjogvi, :legacy, :import, object_type, :start] = _event,
        _measurements,
        %{broadcast_key: broadcast_key} = _metadata,
        _config
      )
      when object_type in [:locations, :checklists, :observations, :images] do
    broadcast(
      broadcast_key,
      %{message: "Importing #{Atom.to_string(object_type)}..."}
    )
  end

  def handle_event(
        [:kjogvi, :legacy, :import, :locations, :after_import, :start] = _event,
        _measurements,
        %{broadcast_key: broadcast_key} = _metadata,
        _config
      ) do
    broadcast(
      broadcast_key,
      %{message: "Caching public locations..."}
    )
  end

  def handle_event(
        [:kjogvi, :legacy, :import, :observations, :after_import, :start] = _event,
        _measurements,
        %{broadcast_key: broadcast_key} = _metadata,
        _config
      ) do
    broadcast(
      broadcast_key,
      %{message: "Promoting observation species..."}
    )
  end

  def handle_event(
        [:kjogvi, :legacy, :import, object_type, :progress] = _event,
        %{count: count} = _measurements,
        %{broadcast_key: broadcast_key} = _metadata,
        _config
      )
      when object_type in [:locations, :checklists, :observations, :images] do
    broadcast(
      broadcast_key,
      %{message: "Importing #{Atom.to_string(object_type)}... #{count}"}
    )
  end

  defp broadcast(nil, _data) do
    :ok
  end

  # The key is an %Oban.Job{} when the import runs as a job — the report is
  # then also recorded on the job row — or a bare task key otherwise.
  defp broadcast(broadcast_key, data) do
    Kjogvi.Jobs.progress(broadcast_key, data)
  end
end
