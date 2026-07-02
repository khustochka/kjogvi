defmodule KjogviWeb.Live.Admin.Locations.Index do
  @moduledoc """
  Admin index of the common locations dataset: the entire shared scaffold as a
  collapsible tree, read-only. Unlike `Live.My.Locations.Index` it shows every
  common location — including countries nothing hangs under yet — and no
  personal locations.
  """

  use KjogviWeb, :live_view

  alias Kjogvi.Geo

  @impl true
  def mount(_params, _session, socket) do
    tree = Geo.common_location_tree()

    {:ok,
     socket
     |> assign(:page_title, "Common Locations")
     |> assign(:location_tree, tree)
     |> assign(:locations_count, count_nodes(tree))}
  end

  defp count_nodes(nodes) do
    Enum.reduce(nodes, 0, fn node, acc -> acc + 1 + count_nodes(node.children) end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex flex-wrap items-end justify-between gap-4">
        <.h1 class="mb-0!">
          Common Locations
        </.h1>
        <div class="inline-flex items-baseline gap-2 bg-forest-600 text-white px-3 py-2 rounded-lg mb-1">
          <span id="common-locations-count" class="text-lg font-header font-bold tracking-tight">
            {@locations_count}
          </span>
          <span class="text-forest-100 text-sm font-medium">locations</span>
        </div>
      </div>

      <div>
        <ul :if={length(@location_tree) > 0} class="space-y-4">
          <li
            :for={node <- @location_tree}
            class="border border-stone-200 rounded-lg overflow-hidden"
          >
            <.tree_node node={node} admin={true} />
          </li>
        </ul>

        <div :if={length(@location_tree) == 0} class="text-center py-8 text-stone-500">
          <.icon name="hero-map-pin" class="w-12 h-12 mx-auto mb-4 text-stone-300" />
          <p class="text-lg font-medium">No common locations yet</p>
          <p class="text-sm">Run the ISO 3166 import to seed the scaffold.</p>
        </div>
      </div>
    </div>
    """
  end
end
