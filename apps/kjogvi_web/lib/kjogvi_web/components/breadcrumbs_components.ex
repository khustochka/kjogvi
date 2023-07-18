defmodule KjogviWeb.BreadcrumbsComponents do
  @moduledoc """
  Components for breadcrumbs.
  """

  use Phoenix.Component

  @doc ~S"""
  Renders a series of breadcrumbs.

  ## Examples

      <.breadcrumbs>
        <:crumb><b><.link href={~p"/taxonomy"}>Taxonomy</.link></b></:crumb>
        <:crumb><%= @book.name %></:crumb>
      </.breadcrumbs>
  """

  slot :crumb

  def breadcrumbs(assigns) do
    ~H"""
    <nav
      role="navigation"
      aria-label="Breadcrumbs"
      class="breadcrumbs mb-6 text-xs"
    >
    <%= for {crumb, i} <- Enum.with_index(@crumb) do %>
    <div class="inline-block"><%= render_slot(crumb) %></div>
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
end
