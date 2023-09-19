defmodule KjogviWeb.MetaComponents do
  @moduledoc """
  Components to render meta tags.
  """
  use Phoenix.Component

  def meta_robots(assigns) do
    ~H"""
    <meta :if={@content} name="robots" content={robots(@content)} />
    """
  end

  defp robots(value) when is_atom(value) do
    Atom.to_string(value)
  end

  defp robots(value) when is_binary(value) do
    value
  end

  defp robots(list) when is_list(list) do
    for value <- list do
      robots(value)
    end
    |> Enum.join(",")
  end
end
