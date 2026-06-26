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

  alias Kjogvi.Accounts.User
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
          <span class="text-sm font-medium text-stone-800">
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
        <span class="text-xs text-stone-500">{@location.slug}</span>
        <.type_badge :if={@location.location_type} type={@location.location_type} />
        <.lifelist_badge :if={Location.show_on_lifelist?(@location)} />
      </div>
    </div>
    """
  end

  @doc """
  Renders a common (country / subdivision) scaffold node in the locations tree.

  Common locations are the shared "big tent" the user's own locations hang under,
  so they read larger and muted, with a flag for countries. They carry no
  edit/delete actions (commons aren't user-owned), only a link to their page and
  a lifelist link.
  """
  attr :location, :map, required: true

  def common_node(assigns) do
    ~H"""
    <div class="flex items-center justify-between gap-2">
      <div class="min-w-0">
        <.link
          href={~p"/my/locations/#{@location.slug}"}
          class={[
            "min-w-0 flex items-center gap-2 font-header tracking-tight text-stone-700 no-underline hover:underline",
            common_node_text_size(@location.location_type)
          ]}
        >
          <span :if={country_flag(@location) != ""} aria-hidden="true">
            {country_flag(@location)}
          </span>
          <span class="truncate">{@location.name_en}</span>
          <span
            :if={@location.iso_code && @location.iso_code != ""}
            class="text-stone-400 font-mono text-sm font-normal shrink-0"
          >
            {String.upcase(@location.iso_code)}
          </span>
          <.icon
            :if={@location.is_private}
            name="hero-lock-closed"
            class="w-4 h-4 text-stone-500 shrink-0"
          />
        </.link>
        <div class="flex flex-wrap items-center gap-x-2 gap-y-1 mt-0.5">
          <span class="text-xs text-stone-400 truncate">{@location.slug}</span>
          <.type_badge :if={@location.location_type} type={@location.location_type} />
        </div>
      </div>
      <.lifelist_link slug={@location.slug} />
    </div>
    """
  end

  @doc """
  Renders a single location, picking the body by kind — common (the tinted
  scaffold header), personal (a row with edit/delete actions), or special (the
  rose, action-less amalgamation row) — over a type-keyed background.

  `variant` controls the surrounding chrome:

    * `:tree` — sits inside a tree branch (the caller supplies the chevron and
      `px-3` wrapper), so the card adds only its type-keyed tint and padding.
    * `:flat` — a standalone card (search results, the specials section), so it
      carries its own padding.

  `current_user` and `delete_error` are only consulted for personal locations.
  """
  attr :location, :map, required: true
  attr :variant, :atom, default: :flat, values: [:tree, :flat]
  attr :current_user, :any, default: nil
  attr :delete_error, :any, default: nil

  def location_card(assigns) do
    assigns = assign(assigns, :kind, location_kind(assigns.location))

    ~H"""
    <div class={location_card_class(@kind, @location.location_type, @variant)}>
      <.common_node :if={@kind == :common} location={@location} />
      <.personal_body
        :if={@kind == :personal}
        location={@location}
        current_user={@current_user}
        delete_error={delete_error_for(@delete_error, @location.id)}
      />
      <.special_body :if={@kind == :special} location={@location} />
    </div>
    """
  end

  defp location_kind(%{location_type: :special}), do: :special
  defp location_kind(%{user_id: nil}), do: :common
  defp location_kind(_), do: :personal

  # Background + padding for a card, keyed on kind/type and variant. Common
  # scaffold reads sky (countries) or amber (subdivisions); specials read rose;
  # personal locations are plain white. `:tree` cards omit horizontal padding —
  # the tree branch wrapper provides it — while `:flat` cards are self-contained.
  # `:flat` cards carry horizontal padding; `:tree` cards leave it to the branch
  # wrapper. Literal class strings (not interpolated) so Tailwind's scanner sees
  # them.
  defp location_card_class(:special, _type, :flat), do: "bg-rose-50 border border-rose-100 p-4"
  defp location_card_class(:special, _type, :tree), do: "bg-rose-50 py-2.5"
  defp location_card_class(:common, :country, :flat), do: "bg-sky-50 px-3 py-2.5"
  defp location_card_class(:common, :country, :tree), do: "bg-sky-50 py-2.5"
  defp location_card_class(:common, :subdivision1, :flat), do: "bg-amber-50 px-3 py-2"
  defp location_card_class(:common, :subdivision1, :tree), do: "bg-amber-50 py-2"
  defp location_card_class(:common, _type, :flat), do: "bg-stone-50 px-3 py-2"
  defp location_card_class(:common, _type, :tree), do: "bg-stone-50 py-2"
  defp location_card_class(:personal, _type, :flat), do: "bg-white px-3 py-3"
  defp location_card_class(:personal, _type, :tree), do: "bg-white py-3"

  attr :location, :map, required: true
  attr :current_user, :any, default: nil
  attr :delete_error, :any, default: nil

  # A personal (user-owned) location: name/details plus edit & delete actions and
  # a lifelist link. Shows the comma-joined long name when it adds detail beyond
  # the bare name, and any inline delete-failure message.
  defp personal_body(assigns) do
    ~H"""
    <div class="flex items-center justify-between gap-2">
      <div class="flex-1 min-w-0">
        <.location_row location={@location} />
        <p
          :if={Location.long_name(:private, @location) != @location.name_en}
          class="mt-1 text-xs text-stone-400"
        >
          {Location.long_name(:private, @location)}
        </p>
      </div>

      <div class="flex flex-col items-end gap-1">
        <div class="flex items-center gap-2">
          <.row_actions
            location={@location}
            can_modify={User.owns?(@current_user, @location)}
          />
          <.lifelist_link slug={@location.slug} />
        </div>
        <p
          :if={@delete_error}
          id={"location-delete-error-#{@location.id}"}
          class="text-right text-xs text-rose-600"
        >
          {@delete_error}
        </p>
      </div>
    </div>
    """
  end

  attr :location, :map, required: true

  # A special location: full name and a lifelist link. Specials sit outside the
  # hierarchy and aren't user-editable here, so they carry no edit/delete actions.
  defp special_body(assigns) do
    ~H"""
    <div class="flex items-center justify-between gap-2">
      <div class="flex-1 min-w-0">
        <.location_row location={@location} />
        <p
          :if={Location.long_name(:private, @location) != @location.name_en}
          class="mt-1 text-xs text-stone-400"
        >
          {Location.long_name(:private, @location)}
        </p>
      </div>
      <.lifelist_link slug={@location.slug} />
    </div>
    """
  end

  # The delete button is shown for every owned location; deletability (no
  # children, no checklists) is enforced server-side by `Geo.delete_location/2`,
  # which flashes an error if the location is still in use. This keeps the list
  # free of a per-row deletability query.
  attr :location, :map, required: true
  attr :can_modify, :boolean, default: false

  defp row_actions(assigns) do
    ~H"""
    <div class="shrink-0 flex items-center gap-1">
      <.link
        :if={@can_modify}
        href={~p"/my/locations/#{@location.slug}/edit"}
        class="p-1.5 text-stone-500 hover:text-stone-800 hover:bg-stone-100 rounded"
        title="Edit"
      >
        <.icon name="hero-pencil-square" class="w-4 h-4" />
      </.link>
      <button
        :if={@can_modify}
        type="button"
        phx-click="delete"
        phx-value-id={@location.id}
        data-confirm={"Delete location \"#{@location.name_en}\"? This cannot be undone."}
        class="p-1.5 text-rose-600 hover:text-rose-800 hover:bg-rose-50 rounded"
        title="Delete"
      >
        <.icon name="hero-trash" class="w-4 h-4" />
      </button>
    </div>
    """
  end

  # The delete-failure message for `id`, or `nil` when the failure (if any) is
  # for a different row.
  defp delete_error_for({id, message}, id), do: message
  defp delete_error_for(_, _), do: nil

  # Countries read largest, subdivisions a step down; deeper commons stay modest.
  defp common_node_text_size(:country), do: "text-xl font-bold"
  defp common_node_text_size(:subdivision1), do: "text-lg font-semibold"
  defp common_node_text_size(_), do: "text-base font-semibold"

  defp country_flag(%{location_type: :country} = location), do: Location.to_flag_emoji(location)
  defp country_flag(_), do: ""

  @doc """
  Renders a lifelist link for a location.
  """
  attr :slug, :string, required: true

  def lifelist_link(assigns) do
    ~H"""
    <.link
      href={~p"/my/lifelist/#{@slug}"}
      class="shrink-0 ml-4 px-2.5 py-1 text-xs sm:text-sm font-medium text-forest-700 bg-forest-50 hover:bg-forest-100 border border-forest-300 rounded no-underline"
    >
      Lifelist
    </.link>
    """
  end

  @doc """
  Renders a colored badge for a location type.
  """
  attr :type, :atom, required: true

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
      :country -> "bg-sky-100 text-sky-700"
      :subdivision1 -> "bg-amber-100 text-amber-700"
      :subdivision2 -> "bg-teal-100 text-teal-700"
      :city -> "bg-violet-100 text-violet-700"
      :site -> "bg-indigo-100 text-indigo-700"
      :section -> "bg-emerald-100 text-emerald-700"
      :special -> "bg-rose-100 text-rose-700"
      _other -> "bg-stone-100 text-stone-600"
    end
  end
end
