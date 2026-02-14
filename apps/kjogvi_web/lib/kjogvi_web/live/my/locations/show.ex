defmodule KjogviWeb.Live.My.Locations.Show do
  @moduledoc false

  use KjogviWeb, :live_view

  alias Kjogvi.Geo

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    location = Geo.location_by_slug_scope(socket.assigns.current_scope, slug)

    if location do
      # Load ancestors for the ancestry table
      ancestors = get_ancestors(location)

      # Get card count for this location
      cards_count = get_cards_count(location.id)

      # Get direct children count
      children_count = get_children_count(location.id)

      {:ok,
       socket
       |> assign(:page_title, location.name_en)
       |> assign(:location, location)
       |> assign(:ancestors, ancestors)
       |> assign(:cards_count, cards_count)
       |> assign(:children_count, children_count)}
    else
      {:ok,
       socket
       |> put_flash(:error, "Location not found")
       |> redirect(to: ~p"/my/locations")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.h1>
      {@location.name_en}
    </.h1>

    <div class="space-y-6">
      <%!-- Location Details Card --%>
      <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-4 sm:p-6">
        <h2 class="text-lg font-semibold text-gray-900 mb-4 flex items-center">
          <.icon name="hero-map-pin" class="w-5 h-5 mr-2 text-blue-500" />
          Location Details
        </h2>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <dt class="text-sm font-medium text-gray-500">Name</dt>
            <dd class="mt-1 text-sm text-gray-900">{@location.name_en}</dd>
          </div>

          <div>
            <dt class="text-sm font-medium text-gray-500">Slug</dt>
            <dd class="mt-1 text-sm text-gray-900 font-mono">{@location.slug}</dd>
          </div>

          <div :if={@location.location_type}>
            <dt class="text-sm font-medium text-gray-500">Type</dt>
            <dd class="mt-1">
              <span class="inline-block px-2 py-1 text-xs font-medium bg-gray-100 text-gray-700 rounded-full">
                {@location.location_type}
              </span>
            </dd>
          </div>

          <div :if={@location.iso_code}>
            <dt class="text-sm font-medium text-gray-500">ISO Code</dt>
            <dd class="mt-1 text-sm text-gray-900 font-mono font-semibold">
              {String.upcase(@location.iso_code)}
            </dd>
          </div>

          <div>
            <dt class="text-sm font-medium text-gray-500">Visibility</dt>
            <dd class="mt-1">
              <span class={[
                "inline-flex items-center px-2 py-1 text-xs font-medium rounded-full",
                if(@location.is_private,
                  do: "bg-red-100 text-red-700",
                  else: "bg-green-100 text-green-700"
                )
              ]}>
                <%= if @location.is_private do %>
                  <.icon name="hero-lock-closed" class="w-3 h-3 mr-1" />
                  Private
                <% else %>
                  <.icon name="hero-globe-alt" class="w-3 h-3 mr-1" />
                  Public
                <% end %>
              </span>
            </dd>
          </div>

          <div :if={@location.lat && @location.lon}>
            <dt class="text-sm font-medium text-gray-500">Coordinates</dt>
            <dd class="mt-1 text-sm text-gray-900 font-mono">
              {@location.lat}, {@location.lon}
            </dd>
          </div>
        </div>

        <%!-- Special attributes --%>
        <div :if={@location.is_patch || @location.is_5mr} class="mt-4 pt-4 border-t border-gray-200">
          <dt class="text-sm font-medium text-gray-500 mb-2">Special Attributes</dt>
          <div class="flex flex-wrap gap-2">
            <span
              :if={@location.is_patch}
              class="inline-flex items-center px-2 py-1 text-xs font-medium bg-yellow-100 text-yellow-700 rounded-full"
            >
              <.icon name="hero-sparkles" class="w-3 h-3 mr-1" />
              Patch
            </span>
            <span
              :if={@location.is_5mr}
              class="inline-flex items-center px-2 py-1 text-xs font-medium bg-blue-100 text-blue-700 rounded-full"
            >
              <.icon name="hero-map" class="w-3 h-3 mr-1" />
              5-Mile Radius
            </span>
          </div>
        </div>
      </div>

      <%!-- Ancestors Table --%>
      <div
        :if={length(@ancestors) > 0}
        class="bg-white rounded-lg shadow-sm border border-gray-200 p-4 sm:p-6"
      >
        <h2 class="text-lg font-semibold text-gray-900 mb-4 flex items-center">
          <.icon name="hero-arrow-trending-up" class="w-5 h-5 mr-2 text-green-500" />
          Location Ancestry
        </h2>

        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Level
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Name
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Type
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  ISO Code
                </th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <%= for {ancestor, index} <- Enum.with_index(@ancestors) do %>
                <tr class="hover:bg-gray-50">
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {index + 1}
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class="flex items-center">
                      <div class="flex-shrink-0 h-8 w-8">
                        <div class="h-8 w-8 bg-blue-100 rounded-full flex items-center justify-center">
                          <.icon name="hero-map-pin" class="h-4 w-4 text-blue-600" />
                        </div>
                      </div>
                      <div class="ml-4">
                        <div class="text-sm font-medium text-gray-900">
                          <.link
                            href={~p"/my/locations/#{ancestor.slug}"}
                            class="underline"
                          >
                            {ancestor.name_en}
                          </.link>
                        </div>
                        <div class="text-sm text-gray-500 font-mono">
                          {ancestor.slug}
                        </div>
                      </div>
                    </div>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span
                      :if={ancestor.location_type}
                      class="inline-block px-2 py-1 text-xs font-medium bg-gray-100 text-gray-700 rounded-full"
                    >
                      {ancestor.location_type}
                    </span>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 font-mono">
                    {if ancestor.iso_code, do: String.upcase(ancestor.iso_code), else: "—"}
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>

      <%!-- Statistics Card --%>
      <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-4 sm:p-6">
        <h2 class="text-lg font-semibold text-gray-900 mb-4 flex items-center">
          <.icon name="hero-chart-bar" class="w-5 h-5 mr-2 text-purple-500" />
          Statistics
        </h2>

        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          <div class="bg-blue-50 rounded-lg p-4">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <.icon name="hero-document-text" class="h-6 w-6 text-blue-600" />
              </div>
              <div class="ml-3">
                <p class="text-sm font-medium text-blue-700">Cards</p>
                <p class="text-2xl font-semibold text-blue-900">{@cards_count}</p>
              </div>
            </div>
          </div>

          <div class="bg-green-50 rounded-lg p-4">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <.icon name="hero-map-pin" class="h-6 w-6 text-green-600" />
              </div>
              <div class="ml-3">
                <p class="text-sm font-medium text-green-700">Child Locations</p>
                <p class="text-2xl font-semibold text-green-900">{@children_count}</p>
              </div>
            </div>
          </div>

          <div class="bg-purple-50 rounded-lg p-4">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <.icon name="hero-arrow-trending-up" class="h-6 w-6 text-purple-600" />
              </div>
              <div class="ml-3">
                <p class="text-sm font-medium text-purple-700">Hierarchy Level</p>
                <p class="text-2xl font-semibold text-purple-900">{length(@ancestors) + 1}</p>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Actions Card --%>
      <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-4 sm:p-6">
        <h2 class="text-lg font-semibold text-gray-900 mb-4 flex items-center">
          <.icon name="hero-adjustments-vertical" class="w-5 h-5 mr-2 text-gray-500" />
          Actions
        </h2>

        <div class="flex flex-wrap gap-3">
          <.link
            href={~p"/my/lifelist/#{@location.slug}"}
            class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            <.icon name="hero-clipboard" class="w-4 h-4 mr-2" />
            View Lifelist
          </.link>

          <.link
            href={~p"/my/locations"}
            class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4 mr-2" />
            Back to Locations
          </.link>
        </div>
      </div>
    </div>
    """
  end

  defp get_ancestors(%{ancestry: []}) do
    []
  end

  defp get_ancestors(location) do
    import Ecto.Query

    from(l in Kjogvi.Geo.Location, where: l.id in ^location.ancestry, order_by: l.id)
    |> Kjogvi.Repo.all()
    |> Enum.sort_by(fn ancestor ->
      Enum.find_index(location.ancestry, &(&1 == ancestor.id))
    end)
  end

  defp get_cards_count(location_id) do
    import Ecto.Query

    from(c in Kjogvi.Birding.Card, where: c.location_id == ^location_id, select: count(c.id))
    |> Kjogvi.Repo.one()
  end

  defp get_children_count(location_id) do
    import Ecto.Query

    from(l in Kjogvi.Geo.Location,
      where: fragment("? @> ?::bigint[]", l.ancestry, [^location_id]),
      select: count(l.id)
    )
    |> Kjogvi.Repo.one()
  end
end
