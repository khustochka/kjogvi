defmodule Kjogvi.Util.PubSubTopic do
  @moduledoc """
  Derives a PubSub topic string from a task key.

  Tuple/list keys are joined with `:` (so `{:legacy_import, 1}` ->
  `"legacy_import:1"`); scalar keys are used as-is. This is the single source of
  truth for the mapping, shared by the broadcasters and the subscribers so the
  topic can't drift between them.
  """

  def for_key(key) when is_tuple(key) do
    key
    |> Tuple.to_list()
    |> for_key()
  end

  def for_key(key) when is_list(key) do
    Enum.join(key, ":")
  end

  def for_key(key) do
    to_string(key)
  end
end
