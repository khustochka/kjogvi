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
        [:kjogvi, :legacy, :import, :cards, :start],
        [:kjogvi, :legacy, :import, :cards, :progress],
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
      when object_type in [:locations, :cards, :observations, :images] do
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
      when object_type in [:locations, :cards, :observations, :images] do
    broadcast(
      broadcast_key,
      %{message: "Importing #{Atom.to_string(object_type)}... #{count}"}
    )
  end

  defp broadcast(nil, _message) do
    :ok
  end

  defp broadcast(broadcast_key, data) do
    Phoenix.PubSub.broadcast(
      Kjogvi.PubSub,
      Kjogvi.Util.PubSubTopic.for_key(broadcast_key),
      {:progress, broadcast_key, data}
    )
  end
end
