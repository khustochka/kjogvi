defmodule KjogviWeb.LifelistComponents do
  @moduledoc """
  Components for lifelist.
  """

  use Phoenix.Component

  import KjogviWeb.IconComponents

  alias Phoenix.LiveView.JS

  attr :selected, :any, required: true, doc: "key of the currently selected item"
  attr :id, :string, required: true

  slot :placeholder, required: true, doc: "placeholder text for selector"

  slot :left, required: true do
    attr :href, :string
  end

  slot :item do
    attr :key, :string
    attr :href, :string
  end

  def bivalve_select(assigns) do
    ~H"""
    <div id={@id} class="bivalve-select" phx-mounted={JS.hide(to: {:inner, ".bivalve-ul-items"})}>
      <ul class="bivalve-ul-selector flex flex-wrap gap-0 mb-2">
        <.bivalve_li :for={left <- @left} data-bivalve-left selected={is_nil(@selected)}>
          <%= if is_nil(@selected) do %>
            <.bivalve_pill_span>
              <em class="not-italic font-bold">{render_slot(left)}</em>
            </.bivalve_pill_span>
          <% else %>
            <.bivalve_pill_link patch={left.href} id={@id}>
              {render_slot(left)}
            </.bivalve_pill_link>
          <% end %>
        </.bivalve_li>

        <.bivalve_li
          data-bivalve-placeholder
          class="relative hover:cursor-pointer"
          selected={not is_nil(@selected)}
          phx-click={JS.toggle(to: "##{@id} .bivalve-ul-items")}
        >
          <.bivalve_pill_span>
            <%= if is_nil(@selected) do %>
              <span class="text-gray-500">
                {render_slot(@placeholder)}
              </span>
            <% else %>
              <em class="not-italic font-bold">
                {render_slot(@placeholder)}
              </em>
            <% end %>
          </.bivalve_pill_span>
          <span class="hidden">▼</span>
          <.icon name="hero-chevron-down-solid" class="w-4 h-4 absolute right-1 top-3" />
        </.bivalve_li>
      </ul>

      <div class="bivalve-ul-items js-hidden-element">
        <ul class="flex flex-wrap gap-0">
          <.bivalve_li :for={item <- @item} data-bivalve-item selected={item.key == @selected}>
            <%= if item.key == @selected do %>
              <.bivalve_pill_span>
                <em class="not-italic font-bold">{render_slot(item)}</em>
              </.bivalve_pill_span>
            <% else %>
              <.bivalve_pill_link patch={item.href} id={@id}>
                {render_slot(item)}
              </.bivalve_pill_link>
            <% end %>
          </.bivalve_li>
        </ul>
      </div>
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :selected, :boolean, default: false
  attr :rest, :global
  slot :inner_block

  defp bivalve_li(assigns) do
    ~H"""
    <li
      class={[
        bivalve_li_classes(),
        @class,
        (@selected && "bg-sky-100 text-sky-900 border-sky-400 z-1") || "border-slate-300"
      ]}
      data-bivalve-selected={@selected}
      {@rest}
    >
      {render_slot(@inner_block)}
    </li>
    """
  end

  attr :id, :string, required: true
  attr :patch, :string, required: true
  slot :inner_block

  defp bivalve_pill_link(assigns) do
    ~H"""
    <.link
      patch={@patch}
      class={[bivalve_pill_classes(), bivalve_link_classes()]}
      phx-click={JS.hide(to: "##{@id} .bivalve-ul-items") |> JS.patch(@patch)}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  defp bivalve_pill_span(assigns) do
    ~H"""
    <span class={[bivalve_pill_classes()]}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  defp bivalve_li_classes do
    "block w-1/2 text-center mb-1 border-1 " <>
      "sm:w-1/4 md:w-1/5 lg:w-1/6 xl:w-1/7 mb-[-1px] mr-[-1px]"
  end

  defp bivalve_pill_classes do
    "block text-center p-2"
  end

  defp bivalve_link_classes do
    "text-sky-600 underline underline-offset-4 decoration-1 decoration-dotted decoration-sky-400"
  end
end
