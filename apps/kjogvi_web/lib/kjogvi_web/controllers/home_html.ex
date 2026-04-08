defmodule KjogviWeb.HomeHTML do
  @moduledoc """
  This module contains pages rendered by HomeController.

  See the `home_html` directory for all templates available.
  """
  use KjogviWeb, :html

  import KjogviWeb.Partials

  embed_templates "home_html/*"
end
