defmodule KjogviWeb.AccessComponents do
  @moduledoc """
  Components related to access restrictions.
  """
  use Phoenix.Component

  @doc """
  Render different content depending on if user is logged in or not.
  """
  attr :user, :any

  slot :logged_in
  slot :guest_access

  def access_control(assigns) do
    ~H"""
    <%= if @user do %>
      {render_slot(@logged_in)}
    <% else %>
      {render_slot(@guest_access)}
    <% end %>
    """
  end
end
