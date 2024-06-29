defmodule Kjogvi.Cache do
  @moduledoc """
  Caching front end.
  """

  @cache_name :kjogvi_cache

  def get(key, opts \\ []) do
    underlying_get(config(), key, opts)
  end

  def put(key, value, opts \\ []) do
    underlying_put(config(), key, value, opts)
  end

  def fetch(key, fallback \\ nil, opts \\ []) do
    underlying_fetch(config(), key, fallback, opts)
  end

  defp underlying_get(%{enabled: true}, key, opts) do
    {_, value} = Cachex.get(@cache_name, key, opts)
    value
  end

  defp underlying_get(_config, _key, _opts) do
    nil
  end

  defp underlying_put(%{enabled: true}, key, value, opts) do
    {_, value} = Cachex.put(@cache_name, key, value, opts)
    value
  end

  defp underlying_put(_config, _key, value, _opts) do
    value
  end

  defp underlying_fetch(%{enabled: true}, key, fallback, opts) do
    {_, value} = Cachex.fetch(@cache_name, key, fallback, opts)
    value
  end

  defp underlying_fetch(_config, key, fallback, _opts) do
    case fallback do
      func when is_function(func) ->
        {_, value} = func.(key)
        value

      val ->
        val
    end
  end

  defp config() do
    Application.get_env(:kjogvi, :cache) |> Enum.into(%{})
  end
end
