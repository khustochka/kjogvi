defmodule Kjogvi.Config do
  @moduledoc """
  Kjogvi configuration reader.
  """

  # def allow_user_registration do
  #   Application.get_env(:kjogvi, :allow_user_registration, false)
  # end

  defmacro with_user_registration(do: body) do
    if Application.get_env(:kjogvi, :allow_user_registration, false) do
      quote do
        unquote(body)
      end
    end
  end

  defmacro with_dev_routes(do: body) do
    if Application.get_env(:kjogvi_web, :dev_routes) do
      quote do
        unquote(body)
      end
    end
  end
end
