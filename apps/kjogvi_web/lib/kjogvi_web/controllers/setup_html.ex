defmodule KjogviWeb.SetupHTML do
  @moduledoc """
  This module contains pages for initial setup.
  """
  use KjogviWeb, :html

  alias KjogviWeb.LoginRegistrationComponents

  embed_templates "setup_html/*"
end
