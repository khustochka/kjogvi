defmodule KjogviWeb.BaseComponents do
  @moduledoc """
  The most basic UI components.

  This module is supposed to gradually replace CoreComponents.
  """
  alias KjogviWeb.IconComponents

  use Phoenix.Component

  import IconComponents

  # alias Phoenix.LiveView.JS
  # use Gettext, backend: KjogviWeb.Gettext

  def link_to_top(assigns) do
    ~H"""
    <div class="text-right my-2 text-gray-400">
      <a
        href="#top"
        class="inline-block px-2 pb-2 border-4 border-gray-300 rounded text-center no-underline"
      >
        <div class="text-xs mb-1">Back to top</div>
        <.icon name="hero-arrow-up-solid w-10 h-10" class="" />
      </a>
    </div>
    """
  end
end
