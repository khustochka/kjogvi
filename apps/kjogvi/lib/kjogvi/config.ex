defmodule Kjogvi.Config do
  @moduledoc """
  Kjogvi configuration reader.
  """

  # def multiuser do
  #   Application.get_env(:kjogvi, :multiuser, false)
  # end

  defmacro with_multiuser(do: body) do
    if Application.get_env(:kjogvi, :multiuser, false) do
      quote do
        unquote(body)
      end
    end
  end

  defmacro with_single_user(do: body) do
    if !Application.get_env(:kjogvi, :multiuser, false) do
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

  def single_user_mode? do
    !Application.get_env(:kjogvi, :multiuser, false)
  end
end
