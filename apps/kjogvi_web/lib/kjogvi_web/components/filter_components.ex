defmodule KjogviWeb.FilterComponents do
  @moduledoc """
  Pill components for filter controls.

  `filter_pill/1` is the visual primitive. Two `<li>` layout wrappers pass
  shape/sizing on top of it:

    * `grid_filter_pill/1` — block, centered, fills its grid cell
      (for compact equal-width grids like sidebar year/month selectors).
    * `inline_filter_pill/1` — inline-block, sized to content
      (for free-flowing flex-wrap filter rows).
  """

  use Phoenix.Component

  @doc """
  Pill shaped to fill an equal-width grid cell — block element with centered
  text. Used in compact grids like sidebar year/month selectors.
  """
  attr :selected, :boolean, default: false
  attr :active, :boolean, default: true
  attr :href, :string, required: true
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def grid_filter_pill(assigns) do
    ~H"""
    <li class={@class}>
      <.filter_pill
        state={pill_state(@selected, @active)}
        href={@href}
        class="block text-center py-2 lg:py-1.5 text-base lg:text-sm leading-snug"
      >
        {render_slot(@inner_block)}
      </.filter_pill>
    </li>
    """
  end

  @doc """
  Pill that flows inline and sizes to its content — for free-flowing
  flex-wrap filter rows and breadcrumb-style pills.
  """
  attr :selected, :boolean, default: false
  attr :active, :boolean, default: true
  attr :href, :string, required: true
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def inline_filter_pill(assigns) do
    ~H"""
    <li class={["inline", @class]}>
      <.filter_pill
        state={pill_state(@selected, @active)}
        href={@href}
        class="inline-block px-3 py-1.5 text-base lg:text-sm leading-snug"
      >
        {render_slot(@inner_block)}
      </.filter_pill>
    </li>
    """
  end

  @doc """
  Visual pill primitive — renders the selected/inactive/default state without
  any layout (no `<li>`, no width/padding). Layout wrappers like
  `grid_filter_pill/1` and `inline_filter_pill/1` pass shape/sizing via `class`.
  """
  attr :state, :atom, values: [:selected, :inactive, :default], required: true
  attr :href, :string, default: nil
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def filter_pill(%{state: :selected} = assigns) do
    ~H"""
    <span class={[
      "font-bold text-forest-800 bg-forest-100 border border-forest-300 rounded",
      @class
    ]}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  def filter_pill(%{state: :inactive} = assigns) do
    ~H"""
    <span class={[
      "text-stone-300 border border-stone-100 rounded bg-transparent",
      @class
    ]}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  def filter_pill(%{state: :default} = assigns) do
    ~H"""
    <.link
      patch={@href}
      class={[
        "text-forest-600 bg-white border border-stone-300 rounded hover:bg-forest-50 active:bg-forest-100 active:border-forest-300 phx-click-loading:bg-forest-50 phx-click-loading:border-forest-200 transition-colors no-underline",
        @class
      ]}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  defp pill_state(true, _active), do: :selected
  defp pill_state(false, false), do: :inactive
  defp pill_state(false, true), do: :default
end
