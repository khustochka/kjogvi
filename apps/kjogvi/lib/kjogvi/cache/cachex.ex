defmodule Kjogvi.Cache.Cachex do
  @moduledoc """
  Cachex cache adapter.
  """

  use Supervisor

  @cache_name :kjogvi_cache

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    children = [
      {Cachex, name: @cache_name}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def get(key, opts) do
    {_, value} = Cachex.get(@cache_name, key, opts)
    value
  end

  def put(key, value, opts) do
    {_, value} = Cachex.put(@cache_name, key, value, opts)
    value
  end

  def fetch(key, fallback, opts) do
    {_, value} = Cachex.fetch(@cache_name, key, fallback, opts)
    value
  end
end
