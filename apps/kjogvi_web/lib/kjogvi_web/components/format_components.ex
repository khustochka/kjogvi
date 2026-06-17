defmodule KjogviWeb.FormatComponents do
  @moduledoc """
  Helpers for formatting.
  """
  use Phoenix.Component

  use Gettext, backend: KjogviWeb.Gettext

  def format_date(date) do
    Calendar.strftime(date, "%-d %b %Y")
  end

  def format_time(%Time{} = time) do
    Calendar.strftime(time, "%H:%M")
  end

  # Form params come back as strings (or "") on a failed submit; pass them
  # through unchanged so the time input re-renders the user's value.
  def format_time(time) when is_binary(time) do
    time
  end

  def format_time(nil) do
    nil
  end
end
