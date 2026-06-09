defmodule Kjogvi.Legacy.Import.PubSub do
  @moduledoc """
  PubSub functionality for legacy import progress tracking.
  """

  def broadcast(nil, _message) do
    :ok
  end

  def broadcast(broadcast_key, data) do
    Phoenix.PubSub.broadcast(
      Kjogvi.PubSub,
      Kjogvi.Util.PubSubTopic.for_key(broadcast_key),
      {:progress, broadcast_key, data}
    )
  end
end
