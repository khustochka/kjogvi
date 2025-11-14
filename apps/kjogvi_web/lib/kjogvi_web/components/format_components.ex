defmodule KjogviWeb.FormatComponents do
  @moduledoc """
  Helpers for formatting.
  """
  use Phoenix.Component

  use Gettext, backend: KjogviWeb.Gettext

  def format_date(date) do
    Calendar.strftime(date, "%-d %b %Y")
  end

  def format_time(nil) do
    nil
  end

  def format_time(time) do
    Calendar.strftime(time, "%H:%M")
  end
end
