defmodule KjogviWeb.IconComponents do
  @moduledoc """
  Components for rendering icons.
  """

  use Phoenix.Component

  @doc """
  Renders an icon.

  Most icons are [Heroicons](https://heroicons.com), referenced by
  `hero-<name>` (outline by default; add `-solid` or `-mini` suffix
  for those styles). Heroicons are extracted from the `deps/heroicons`
  directory and bundled into your compiled `app.css`.

  A small number of bespoke icons are bundled as inline SVG and
  referenced by their bare name (e.g. `"car-slash"`).

  You can customize the size and colors of the icons by setting
  width, height, and color classes.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 w-3 h-3 animate-spin" />
      <.icon name="car-slash" class="h-4 w-4" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  # A car in side profile, slashed. The mask cuts a gap around the slash; its id
  # is unique per render so several instances can share a page.
  def icon(%{name: "car-slash"} = assigns) do
    assigns = assign(assigns, :mask_id, "car-slash-mask-#{System.unique_integer([:positive])}")

    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
      class={@class}
    >
      <defs>
        <mask id={@mask_id} maskUnits="userSpaceOnUse" x="0" y="0" width="24" height="24">
          <rect width="24" height="24" fill="#fff" />
          <path d="M3 3l18 18" stroke="#000" stroke-width="4.5" />
        </mask>
      </defs>
      <g mask={"url(##{@mask_id})"}>
        <path d="M4.9 16H3a.75.75 0 0 1-.75-.75v-2.1a1.5 1.5 0 0 1 1.05-1.43l2.95-.92 2.3-3.2a1.5 1.5 0 0 1 1.22-.62h5.06a1.5 1.5 0 0 1 1.15.54L19 11.1h.75a2 2 0 0 1 2 2v2.15a.75.75 0 0 1-.75.75h-1.9M14.9 16H9.1" />
        <path d="M6.25 10.8H19M12.25 7v3.8" />
        <circle cx="7" cy="16" r="2.1" />
        <circle cx="17" cy="16" r="2.1" />
      </g>
      <path d="M3 3l18 18" />
    </svg>
    """
  end
end
