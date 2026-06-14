defmodule KjogviWeb.HomeHTML do
  @moduledoc """
  This module contains pages rendered by HomeController.

  See the `home_html` directory for all templates available.
  """
  use KjogviWeb, :html

  alias Kjogvi.Accounts.User

  embed_templates "home_html/*"
end
