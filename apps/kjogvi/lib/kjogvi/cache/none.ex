defmodule Kjogvi.Cache.None do
  @moduledoc """
  Non-caching cache adapter.
  """

  def start_link(_arg) do
    :ignore
  end

  def get(_key, _opts) do
    nil
  end

  def put(_key, value, _opts) do
    value
  end

  def fetch(key, fallback, _opts) do
    case fallback do
      func when is_function(func) ->
        {_, value} = func.(key)
        value

      val ->
        val
    end
  end
end
