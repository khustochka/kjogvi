defmodule KjogviWeb.Paths do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      import KjogviWeb.Paths.LifelistPath
    end
  end

  @doc """
  Removes keys with `false` and `nil` values from query
  """
  def clean_query(query) do
    Enum.reject(query, fn {_, val} -> !val end)
  end
end
