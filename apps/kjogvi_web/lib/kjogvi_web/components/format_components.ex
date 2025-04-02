defmodule KjogviWeb.FormatComponents do
  @moduledoc """
  Helpers for formatting.
  """
  use Phoenix.Component

  use Gettext, backend: KjogviWeb.Gettext

  def format_observation_date(observ_date) do
    Timex.format!(observ_date, "{D} {Mshort} {YYYY}")
  end
end
