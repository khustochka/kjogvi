defmodule KjogviWeb.MenuBarComponents do
  @moduledoc """
  Components for the top menu bars (private, admin, and login menus).
  """
  use Phoenix.Component

  @doc """
  Renders a menu bar item.
  """
  slot :inner_block, required: true

  def menu_bar_item(assigns) do
    ~H"""
    <li class="text-[0.95rem] md:text-[0.85rem] inline-block mx-2 text-zinc-300 hover:text-white">
      {render_slot(@inner_block)}
    </li>
    """
  end
end
