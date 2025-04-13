defmodule KjogviWeb.FormatComponents do
  @moduledoc """
  Helpers for formatting.
  """
  use Phoenix.Component

  use Gettext, backend: KjogviWeb.Gettext

  def format_date(date) do
    Timex.format!(date, "{D} {Mshort} {YYYY}")
  end

  def format_time(nil) do
    nil
  end

  def format_time(time) do
    Timex.format!(time, "{h24}:{m}")
  end
end
