defmodule Kjogvi.Cache do
  @moduledoc """
  Caching front end.
  """

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def start_link(arg) do
    adapter().start_link(arg)
  end

  def get(key, opts \\ []) do
    adapter().get(key, opts)
  end

  def put(key, value, opts \\ []) do
    adapter().put(key, value, opts)
  end

  def fetch(key, fallback \\ nil, opts \\ []) do
    adapter().fetch(key, fallback, opts)
  end

  defp config() do
    Application.get_env(:kjogvi, :cache) |> Enum.into(%{})
  end

  defp adapter() do
    adapter(config())
  end

  defp adapter(%{enabled: true}) do
    Kjogvi.Cache.Cachex
  end

  defp adapter(_) do
    Kjogvi.Cache.None
  end
end
