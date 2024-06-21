defmodule KjogviWeb.IconComponents do
  @moduledoc """
  Components for rendering icons.
  """

  use Phoenix.Component

  @doc """
  Renders a [Heroicon](https://heroicons.com) or FontAwesome icon.

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in your `assets/tailwind.config.js`.

  FontAwesome icon names have the format: fa-<name>-<style>. Style is
  `regular`, `solid` or `brands`.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 w-3 h-3 animate-spin" />

      <.icon name="fa-solid-bicycle" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  def icon(%{name: "fa-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end
end
