defmodule KjogviWeb.LocationComponents do
  @moduledoc """
  Reusable components for displaying location information.
  """

  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: KjogviWeb.Endpoint,
    router: KjogviWeb.Router,
    statics: KjogviWeb.static_paths()

  import KjogviWeb.IconComponents

  alias Kjogvi.Geo.Location

  @doc """
  Renders a location row with name link, privacy icon, ISO code, slug, and type badge.
  """
  attr :location, :map, required: true

  def location_row(assigns) do
    ~H"""
    <div class="min-w-0">
      <div class="flex flex-col sm:flex-row sm:items-center sm:space-x-2 space-y-0.5 sm:space-y-0">
        <div class="flex items-center space-x-2 min-w-0">
          <span class="text-sm font-medium text-stone-800 truncate">
            <.link
              href={~p"/my/locations/#{@location.slug}"}
              class="text-stone-800 hover:underline no-underline"
            >
              {@location.name_en}
            </.link>
          </span>
          <%= if @location.is_private do %>
            <span title="Private">
              <.icon name="hero-lock-closed" class="w-4 h-4 text-stone-700 shrink-0" />
            </span>
          <% end %>
          <span
            :if={@location.iso_code && @location.iso_code != ""}
            class="text-stone-500 font-mono text-sm shrink-0"
          >
            {String.upcase(@location.iso_code)}
          </span>
        </div>
      </div>
      <div class="flex flex-wrap items-center gap-x-2 gap-y-1 mt-0.5">
        <span class="text-xs text-stone-500 truncate">{@location.slug}</span>
        <.type_badge :if={@location.location_type} type={@location.location_type} />
        <.lifelist_badge :if={Location.show_on_lifelist?(@location)} />
      </div>
    </div>
    """
  end

  @doc """
  Renders a lifelist link for a location.
  """
  attr :slug, :string, required: true

  def lifelist_link(assigns) do
    ~H"""
    <.link
      href={~p"/my/lifelist/#{@slug}"}
      class="shrink-0 ml-4 px-2.5 py-1 text-xs sm:text-sm font-medium text-forest-600 bg-forest-50 hover:bg-forest-100 rounded no-underline"
    >
      Lifelist
    </.link>
    """
  end

  @doc """
  Renders a colored badge for a location type.
  """
  attr :type, :string, required: true

  def type_badge(assigns) do
    ~H"""
    <span class={[
      "inline-block px-2 py-0.5 text-xs font-medium rounded-full shrink-0",
      type_badge_classes(@type)
    ]}>
      {@type}
    </span>
    """
  end

  @doc """
  Renders a badge indicating the location is shown in lifelist filters.
  """
  def lifelist_badge(assigns) do
    ~H"""
    <span class="inline-block px-2 py-0.5 text-xs font-medium rounded-full shrink-0 bg-forest-100 text-forest-600">
      lifelist filter
    </span>
    """
  end

  @doc """
  Renders a Google Static Maps image centered on given coordinates.

  Links through to Google Maps in a new tab. Renders nothing when coordinates
  or the `GOOGLE_MAPS_API_KEY` env var are missing.
  """
  attr :lat, :any, required: true
  attr :lon, :any, required: true
  attr :alt, :string, default: "Map"
  attr :zoom, :integer, default: 12
  attr :size, :string, default: "600x300"
  attr :maptype, :string, default: "roadmap", values: ~w(roadmap satellite hybrid terrain)
  attr :class, :string, default: "w-full max-w-2xl rounded-lg border border-stone-200"
  attr :rest, :global

  def static_map(assigns) do
    assigns = assign(assigns, :url, static_map_url(assigns))

    ~H"""
    <a
      :if={@url}
      href={"https://www.google.com/maps/search/?api=1&query=#{@lat},#{@lon}"}
      target="_blank"
      rel="noopener"
      class="block"
      {@rest}
    >
      <img src={@url} alt={@alt} class={@class} loading="lazy" />
    </a>
    """
  end

  defp static_map_url(%{lat: lat, lon: lon, zoom: zoom, size: size, maptype: maptype})
       when not is_nil(lat) and not is_nil(lon) do
    case Application.get_env(:kjogvi_web, :google_maps, [])[:api_key] do
      key when is_binary(key) and key != "" ->
        coords = "#{lat},#{lon}"

        query =
          URI.encode_query(%{
            "center" => coords,
            "zoom" => Integer.to_string(zoom),
            "size" => size,
            "scale" => "2",
            "maptype" => maptype,
            "markers" => "color:red|#{coords}",
            "key" => key
          })

        "https://maps.googleapis.com/maps/api/staticmap?" <> query

      _ ->
        nil
    end
  end

  defp static_map_url(_), do: nil

  @doc """
  Returns Tailwind classes for a location type badge.
  """
  def type_badge_classes(type) do
    case type do
      "continent" -> "bg-indigo-100 text-indigo-700"
      "country" -> "bg-sky-100 text-sky-700"
      "region" -> "bg-amber-100 text-amber-700"
      "city" -> "bg-violet-100 text-violet-700"
      "raion" -> "bg-teal-100 text-teal-700"
      "special" -> "bg-rose-100 text-rose-700"
      _other -> "bg-stone-100 text-stone-600"
    end
  end
end
