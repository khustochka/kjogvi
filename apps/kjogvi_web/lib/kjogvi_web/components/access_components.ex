defmodule KjogviWeb.AccessComponents do
  @moduledoc """
  Components related to access restrictions.
  """
  use Phoenix.Component

  @doc "Rendered if the user is logged in"
  def logged_in(assigns) do
    ~H"""
    <%= if @current_user do %>
    <% end %>
    """
  end

  @doc "Rendered if the user is a guest (not logged in)"
  def guest_access(assigns) do
    ~H"""

    """
  end
end
