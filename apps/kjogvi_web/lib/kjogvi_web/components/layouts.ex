defmodule KjogviWeb.Layouts do
  @moduledoc false

  use KjogviWeb, :html

  embed_templates "layouts/*"

  def robots(value) when is_atom(value) do
    Atom.to_string(value)
  end

  def robots(value) when is_binary(value) do
    value
  end

  def robots(list) when is_list(list) do
    for value <- list do
      robots(value)
    end
    |> Enum.join(",")
  end
end
