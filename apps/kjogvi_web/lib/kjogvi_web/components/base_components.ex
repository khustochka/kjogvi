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

  Overall style can be overwritten with `header_style`: pass :h1, :h2, :h3 etc.

  To override any of the default styles add ! at the start, e.g. !font-medium
  """
  attr :class, :any, default: "", doc: "String or list"
  attr :header_style, :atom, default: :h1

  slot :inner_block, required: true

  def h1(assigns) do
    ~H"""
    <h1 class={h_style(@header_style, @class)}>
      {render_slot(@inner_block)}
    </h1>
    """
  end

  @doc """
  Renders an header element, potentially with subheader.

  To override any of the default styles add ! at the start, e.g. !font-medium
  """
  attr :class, :any, default: "", doc: "String or list"

  slot :inner_block, required: true
  slot :subheader

  def header_with_subheader(assigns) do
    ~H"""
    <div class="mb-6">
      <.h1 class={[
        "!mb-0",
        @class
      ]}>
        {render_slot(@inner_block)}
      </.h1>
      <div :if={@subheader != []} class="mt-2 font-header font-semibold text-xl text-zinc-400">
        {render_slot(@subheader)}
      </div>
    </div>
    """
  end

  @doc """
  Renders an h2 element.

  Overall style can be overwritten with `header_style`: pass :h1, :h2, :h3 etc.

  To override any of the default styles add ! at the start, e.g. !font-medium
  """
  attr :class, :any, default: "", doc: "String or list"
  attr :header_style, :atom, default: :h2

  slot :inner_block, required: true

  def h2(assigns) do
    ~H"""
    <h1 class={h_style(@header_style, @class)}>
      {render_slot(@inner_block)}
    </h1>
    """
  end

  defp h_style(:h1, class) do
    [
      "font-header",
      "font-semibold",
      "text-zinc-600",
      "text-5xl",
      "leading-snug",
      "mt-6",
      "mb-8",
      class
    ]
  end

  defp h_style(:h2, class) do
    [
      "font-header",
      "font-semibold",
      "text-zinc-600",
      "text-2xl",
      "leading-[1.4]",
      # "mt-0",
      "mb-8",
      class
    ]
  end
end
