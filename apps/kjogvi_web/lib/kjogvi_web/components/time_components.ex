defmodule KjogviWeb.TimeComponents do
  @moduledoc """
  Components for working with date and time.
  """

  use Phoenix.Component

  # alias Phoenix.LiveView.JS
  # import KjogviWeb.Gettext

  @doc """
  Renders datetime.
  """
  attr :time, :any, required: true

  def datetime(%{time: _} = assigns) do
    ~H"""
    <%= if assigns.time do %>
      <time datetime={assigns.time}>
        <nobr>
          <%= Calendar.strftime(assigns.time, "%-d %b %Y") %>
        </nobr>
        <nobr>
          <%= Calendar.strftime(assigns.time, "%X") %>
        </nobr>
      </time>
    <% end %>
    """
  end
end
