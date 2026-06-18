defmodule OrnithoWeb.BreadcrumbsComponents do
  @moduledoc """
  Components for breadcrumbs.
  """

  use Phoenix.Component

  @doc ~S"""
  Renders a series of breadcrumbs.

  ## Examples

      <.breadcrumbs>
        <:crumb><b><.breadcrumb_link href={OrnithoWeb.LinkHelper.root_path(@conn)}>Taxonomy</.breadcrumb_link></b></:crumb>
        <:crumb><%= @book.name %></:crumb>
      </.breadcrumbs>
  """

  slot :crumb

  def breadcrumbs(assigns) do
    ~H"""
    <nav role="navigation" aria-label="Breadcrumbs" class="breadcrumbs mb-6 text-xs">
      <%= for {crumb, i} <- Enum.with_index(@crumb) do %>
        <div class="inline-block">{render_slot(crumb)}</div>
        <.breadcrumbs_separator :if={i < length(@crumb) - 1} />
      <% end %>
    </nav>
    """
  end

  defp breadcrumbs_separator(assigns) do
    ~H"""
    <span class="mx-1 text-sm text-zinc-400">/</span>
    """
  end

  @doc """
  Renders a breadcrumb link in the brand color.

  Forwards `navigate`, `patch`, `href` and any other attributes to `<.link>`.
  The brand color may be overridden by a host app, so embedded breadcrumbs pick
  up the host's brand.
  """
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(navigate patch href method download name target)
  slot :inner_block, required: true

  def breadcrumb_link(assigns) do
    ~H"""
    <.link class={["text-brand hover:text-brand/80", @class]} {@rest}>{render_slot(@inner_block)}</.link>
    """
  end
end
