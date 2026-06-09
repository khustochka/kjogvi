defmodule Kjogvi.Telemetry.LegacyBroadcast do
  @moduledoc false

  alias Kjogvi.Legacy.Import
  alias Kjogvi.Util.AsyncResult

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
        [:kjogvi, :legacy, :import, :stop]
      ],
      &__MODULE__.handle_event/4,
      nil
    )
  end

  # FIXME: Ideally lifecycle updates should be managed by processor. But how we deliver
  # them to the caller?
  def handle_event(
        [:kjogvi, :legacy, :import, :stop] = _event,
        _measurements,
        %{broadcast_key: broadcast_key} = _metadata,
        _config
      ) do
    Import.PubSub.broadcast(broadcast_key, AsyncResult.ok(%{message: "Legacy import done."}))
  end

  def handle_event(
        [:kjogvi, :legacy, :import, :prepare, :start] = _event,
        _measurements,
        %{broadcast_key: broadcast_key} = _metadata,
        _config
      ) do
    Import.PubSub.broadcast(
      broadcast_key,
      AsyncResult.loading(%{message: "Preparing legacy import..."})
    )
  end

  def handle_event(
        [:kjogvi, :legacy, :import, object_type, :start] = _event,
        _measurements,
        %{broadcast_key: broadcast_key} = _metadata,
        _config
      )
      when object_type in [:locations, :cards, :observations] do
    Import.PubSub.broadcast(
      broadcast_key,
      AsyncResult.loading(%{message: "Importing #{Atom.to_string(object_type)}..."})
    )
  end

  def handle_event(
        [:kjogvi, :legacy, :import, :locations, :after_import, :start] = _event,
        _measurements,
        %{broadcast_key: broadcast_key} = _metadata,
        _config
      ) do
    Import.PubSub.broadcast(
      broadcast_key,
      AsyncResult.loading(%{message: "Caching public locations..."})
    )
  end

  def handle_event(
        [:kjogvi, :legacy, :import, :observations, :after_import, :start] = _event,
        _measurements,
        %{broadcast_key: broadcast_key} = _metadata,
        _config
      ) do
    Import.PubSub.broadcast(
      broadcast_key,
      AsyncResult.loading(%{message: "Promoting observation species..."})
    )
  end

  def handle_event(
        [:kjogvi, :legacy, :import, object_type, :progress] = _event,
        %{count: count} = _measurements,
        %{broadcast_key: broadcast_key} = _metadata,
        _config
      )
      when object_type in [:locations, :cards, :observations] do
    Import.PubSub.broadcast(
      broadcast_key,
      AsyncResult.loading(%{message: "Importing #{Atom.to_string(object_type)}... #{count}"})
    )
  end
end
