defmodule KjogviWeb.AdminMenuComponents do
  @moduledoc """
  Components related to admin menu.
  """
  use Phoenix.Component

  @doc """
  Renders admin menu item.
  """
  slot :inner_block, required: true

  def admin_menu_item(assigns) do
    ~H"""
    <li class="text-[0.95rem] md:text-[0.85rem] inline-block mx-2 text-zinc-300 hover:text-white">
      {render_slot(@inner_block)}
    </li>
    """
  end
end
