defmodule Kjogvi.Legacy.Import.PubSub do
  @moduledoc """
  PubSub functionality for legacy import progress tracking.
  """

  def broadcast(nil, _message) do
    :ok
  end

  def broadcast(import_id, message) do
    Phoenix.PubSub.broadcast(
      Kjogvi.PubSub,
      progress_key(import_id),
      {:legacy_import_progress, %{message: message}}
    )
  end

  def subscribe(import_id) do
    Phoenix.PubSub.subscribe(Kjogvi.PubSub, progress_key(import_id))
  end

  defp progress_key(import_id) do
    "legacy.import:progress:#{import_id}"
  end
end
