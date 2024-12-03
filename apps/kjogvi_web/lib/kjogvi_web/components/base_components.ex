defmodule KjogviWeb.BaseComponents do
  @moduledoc """
  The most basic UI components.

  This module is supposed to gradually replace CoreComponents.
  """

  use Phoenix.Component

  # alias Phoenix.LiveView.JS
  # use Gettext, backend: KjogviWeb.Gettext

  @doc """
  Renders an h1 element, single (no wrapper, no subheader).

  `font_style` can be "semibold", "medium" or any other Tailwind class that combines with font-.
  """
  attr :font_style, :string, default: "semibold"
  attr :class, :string, default: ""

  slot :inner_block, required: true

  def header_single(assigns) do
    ~H"""
    <h1 class={[
      "text-5xl",
      "font-header",
      "font-#{@font_style}",
      "leading-none",
      "text-zinc-600",
      "mt-6",
      "mb-8",
      @class
    ]}>
      {render_slot(@inner_block)}
    </h1>
    """
  end

  @doc """
  Renders an header element, potentially with subheader.

  `font_style` can be "semibold", "medium" or any other Tailwind class that combines with font-.
  """
  attr :font_style, :string, default: "semibold"
  attr :class, :string, default: ""

  slot :inner_block, required: true
  slot :subheader

  def header(assigns) do
    ~H"""
    <div class="mb-6">
      <h1 class={[
        "text-5xl",
        "font-header",
        "font-#{@font_style}",
        "leading-none",
        "text-zinc-600",
        "mt-6",
        @class
      ]}>
        {render_slot(@inner_block)}
      </h1>
      <div :if={@subheader != []} class="mt-2 font-header font-semibold text-xl text-zinc-400">
        {render_slot(@subheader)}
      </div>
    </div>
    """
  end
end
