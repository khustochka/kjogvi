defmodule KjogviWeb.NavigationComponents do
  @moduledoc """
  Semantic link and navigation components.
  """
  use Phoenix.Component

  import KjogviWeb.IconComponents

  @doc """
  Renders a link styled as an action button.

  Used for primary actions like "New Checklist", "Edit Checklist", and secondary actions like "Cancel".

  ## Examples

      <.action_button navigate={~p"/my/checklists/new"} icon="hero-plus">New Checklist</.action_button>
      <.action_button navigate={~p"/my/checklists"} variant="secondary">Cancel</.action_button>
  """
  attr :navigate, :string, default: nil
  attr :patch, :string, default: nil
  attr :href, :string, default: nil
  attr :icon, :string, default: nil
  attr :variant, :string, default: "primary", values: ["primary", "secondary"]
  attr :rest, :global
  slot :inner_block, required: true

  def action_button(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      patch={@patch}
      href={@href}
      class={[
        "inline-flex items-center gap-2 rounded-lg px-4 py-2 text-sm font-semibold no-underline",
        variant_classes(@variant)
      ]}
      {@rest}
    >
      <.icon :if={@icon} name={@icon} class="w-4 h-4" />
      {render_slot(@inner_block)}
    </.link>
    """
  end

  defp variant_classes("primary"), do: "bg-blue-600 text-white hover:bg-blue-700"
  defp variant_classes("secondary"), do: "bg-gray-200 text-gray-800 hover:bg-gray-300"

  @doc """
  Renders a breadcrumb navigation link.

  No underline at rest, underline on hover. Designed for use within breadcrumb trails
  where the navigational context makes clickability obvious.

  ## Examples

      <.breadcrumb_link href={~p"/my/locations"}>All locations</.breadcrumb_link>
  """
  attr :navigate, :string, default: nil
  attr :patch, :string, default: nil
  attr :href, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def breadcrumb_link(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      patch={@patch}
      href={@href}
      class="text-forest-600 no-underline hover:underline"
      {@rest}
      phx-no-format
    >{render_slot(@inner_block)}</.link>
    """
  end

  @doc """
  Renders an icon-only link with an accessible label.

  Always requires a `label` for screen readers via `aria-label`.

  ## Examples

      <.icon_link navigate={~p"/my/checklists/1/edit"} icon="hero-pencil-square" label="Edit checklist" />
      <.icon_link navigate={~p"/my/checklists/1"} icon="hero-clipboard-document-list" label="View checklist" class="text-gray-400" />
  """
  attr :navigate, :string, default: nil
  attr :patch, :string, default: nil
  attr :href, :string, default: nil
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block

  def icon_link(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      patch={@patch}
      href={@href}
      aria-label={@label}
      class={@class}
      {@rest}
    >
      <.icon name={@icon} class="w-4 h-4" />
    </.link>
    """
  end

  @doc """
  Pill-style sub-navigation linking the sibling pages of a section.

  The `current` item renders as a non-link highlighted pill; the others as
  links. Used to switch between the Locations, eBird, and Imports admin pages.

  ## Examples

      <.section_nav>
        <:item href={~p"/admin/locations"} current>Common</:item>
        <:item href={~p"/admin/ebird/locations"}>eBird</:item>
        <:item href={~p"/admin/imports"}>Imports</:item>
      </.section_nav>
  """
  attr :class, :any, default: nil

  slot :item, required: true do
    attr :href, :string, required: true
    attr :current, :boolean
  end

  def section_nav(assigns) do
    ~H"""
    <nav class={@class}>
      <ul class="flex flex-wrap items-baseline gap-2">
        <li :for={item <- @item} class="inline">
          <span
            :if={item[:current]}
            aria-current="page"
            class="inline-block px-3 py-1.5 text-base lg:text-sm leading-snug font-bold text-forest-800 bg-forest-100 border border-forest-300 rounded"
          >{render_slot(item)}</span>
          <.link
            :if={!item[:current]}
            navigate={item.href}
            class="inline-block px-3 py-1.5 text-base lg:text-sm leading-snug text-forest-600 bg-white border border-stone-400 rounded hover:bg-forest-50 no-underline"
            phx-no-format
          >{render_slot(item)}</.link>
        </li>
      </ul>
    </nav>
    """
  end

  attr :id, :string
  attr :action, :string, required: true
  attr :method, :string, default: "post"
  attr :class, :string
  slot :inner_block, required: true

  def form_as_link(assigns) do
    ~H"""
    <form action={@action} method="post" id={@id}>
      <input type="hidden" name="_method" value={@method} />
      <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
      <button class={@class}>
        {render_slot(@inner_block)}
      </button>
    </form>
    """
  end
end
