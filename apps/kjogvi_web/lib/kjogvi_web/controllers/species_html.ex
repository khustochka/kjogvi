defmodule KjogviWeb.SpeciesHTML do
  @moduledoc """
  This module contains pages rendered by SpeciesController.

  See the `species_html` directory for all templates available.
  """
  use KjogviWeb, :html

  embed_templates "species_html/*"

  def show(assigns) do
    ~H"""
    <.h1>
      {@species.name_sci}
    </.h1>
    """
  end
end
