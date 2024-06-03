defmodule KjogviWeb.AdminMenuComponents do
  @moduledoc """
  Components related to admin menu.
  """
  use Phoenix.Component

  @doc """
  Renders admin menu.
  """
  slot :inner_block, required: true

  def admin_menu(assigns) do
    ~H"""
    <div class="bg-zinc-900 text-sm font-semibold my-auto text-center py-1 px-3">
      <ul>
        <%= render_slot(@inner_block) %>
      </ul>
    </div>
    """
  end

  @doc """
  Renders admin menu item.
  """
  slot :inner_block, required: true

  def admin_menu_item(assigns) do
    ~H"""
    <li class="inline-block mx-3 text-zinc-200 hover:text-white">
      <%= render_slot(@inner_block) %>
    </li>
    """
  end
end
