defmodule Kjogvi.Config do
  @moduledoc """
  Kjogvi configuration reader.
  """

  defmacro with_dev_routes(do: body) do
    if Application.get_env(:kjogvi_web, :dev_routes) do
      quote do
        unquote(body)
      end
    end
  end
end
