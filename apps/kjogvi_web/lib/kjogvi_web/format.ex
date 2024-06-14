defmodule KjogviWeb.Format do
  @moduledoc """
  Most common formattings.
  """

  def observation_date(%{observ_date: observ_date}) do
    Timex.format!(observ_date, "{D} {Mshort} {YYYY}")
  end
end
