defmodule OrnithoWeb.TimeComponents do
  @moduledoc """
  Components for working with date and time.
  """

  use Phoenix.Component

  @doc """
  Renders datetime in two rows in a human-readable format.

  ## Examples

      <.datetime time={@book.imported_at} />
  """
  attr :time, :any, required: true

  def datetime(assigns) do
    ~H"""
    <time :if={@time} datetime={@time}>
      <nobr>
        {Calendar.strftime(@time, "%-d %b %Y")}
      </nobr>
      <nobr>
        {Calendar.strftime(@time, "%m:%S")}
      </nobr>
    </time>
    """
  end
end
