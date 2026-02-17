defmodule KjogviWeb.NavigationComponents do
  @moduledoc """
  Semantic link and navigation components.
  """
  use Phoenix.Component

  import KjogviWeb.IconComponents

  @doc """
  Renders a link styled as an action button.

  Used for primary actions like "New Card", "Edit Card", and secondary actions like "Cancel".

  ## Examples

      <.action_button navigate={~p"/my/cards/new"} icon="hero-plus">New Card</.action_button>
      <.action_button navigate={~p"/my/cards"} variant="secondary">Cancel</.action_button>
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
      <.breadcrumb_link patch={~p"/lifelist"}>World</.breadcrumb_link>
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

      <.icon_link navigate={~p"/my/cards/1/edit"} icon="hero-pencil-square" label="Edit card" />
      <.icon_link navigate={~p"/my/cards/1"} icon="hero-clipboard-document-list" label="View card" class="text-gray-400" />
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

  attr :action, :string, required: true
  attr :method, :string, default: "post"
  attr :class, :string
  slot :inner_block, required: true

  def form_as_link(assigns) do
    ~H"""
    <form action={@action} method="post">
      <input type="hidden" name="_method" value={@method} />
      <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
      <button class={@class}>
        {render_slot(@inner_block)}
      </button>
    </form>
    """
  end
end
