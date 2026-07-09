defmodule KjogviWeb.Live.My.Settings.Preferences do
  @moduledoc false

  use KjogviWeb, :live_view

  alias Kjogvi.Accounts
  alias Kjogvi.Birding.Lifelist
  alias Kjogvi.Geo

  def render(assigns) do
    ~H"""
    <.h1>Account Settings</.h1>

    <.account_settings active={:preferences}>
      <.h2>Preferences</.h2>

      <.form
        for={@settings_form}
        id="settings_form"
        phx-change="validate_settings"
        phx-submit="update_settings"
      >
        <div class="mt-8 space-y-8 bg-white">
          <CoreComponents.input
            field={@settings_form[:default_book_signature]}
            type="select"
            label="Default taxonomy"
            options={@book_options}
            prompt="Select default taxonomy..."
          />

          <h3 class="text-xl font-header font-semibold leading-none text-zinc-500 mt-6">
            eBird settings
          </h3>
          <.inputs_for :let={preferences_form} field={@settings_form[:preferences]}>
            <.inputs_for :let={ebird_form} field={preferences_form[:ebird]}>
              <CoreComponents.input
                field={ebird_form[:username]}
                label="Username"
                id="ebird_username"
                value={@preferences.ebird.username}
              />
              <div>
                <.input
                  field={ebird_form[:password]}
                  type="password"
                  label="Password"
                  id="ebird_password"
                  value={@preferences.ebird.password}
                />
              </div>
            </.inputs_for>
          </.inputs_for>
          <h3
            id="logbook-settings"
            class="text-xl font-header font-semibold leading-none text-zinc-500 mt-6 scroll-mt-4"
          >
            Logbook settings
          </h3>
          <p class="text-sm text-zinc-500 mb-2">
            Choose which lists to include in the recent additions logbook.
          </p>

          <table class="w-full md:max-w-lg text-sm">
            <thead>
              <tr class="border-b border-zinc-200">
                <th class="text-left py-2 font-semibold">Location</th>
                <th class="text-center py-2 font-semibold w-20">Life</th>
                <th class="text-center py-2 font-semibold w-20">Year</th>
              </tr>
            </thead>
            <tbody>
              <%= for {row, i} <- Enum.with_index(@logbook_location_rows) do %>
                <tr class="border-b border-zinc-300">
                  <td class="py-2">
                    <input
                      type="hidden"
                      name={"user[preferences][logbook_settings][#{i}][location_id]"}
                      value={row.location_id || ""}
                    />
                    <span :if={row.location_id == nil} class="inline-flex items-center gap-1">
                      <.icon name="hero-globe-americas-solid" class="h-4 w-4 text-gray-500" /> {row.name}
                    </span>
                    <span
                      :if={row.location_id != nil && !row.nested && row.flag}
                      class="inline-flex items-center gap-1"
                    >
                      <span>{row.flag}</span> {row.name}
                    </span>
                    <span :if={row.location_id != nil && !row.nested && !row.flag}>
                      {row.name}
                    </span>
                    <span :if={row.nested} class="pl-6">
                      {row.name}
                    </span>
                  </td>
                  <td class="text-center py-2">
                    <input
                      type="hidden"
                      name={"user[preferences][logbook_settings][#{i}][life]"}
                      value="false"
                    />
                    <input
                      type="checkbox"
                      name={"user[preferences][logbook_settings][#{i}][life]"}
                      value="true"
                      checked={row.life}
                      class="rounded border-zinc-300 text-zinc-900 focus:ring-zinc-900"
                    />
                  </td>
                  <td class="text-center py-2">
                    <input
                      type="hidden"
                      name={"user[preferences][logbook_settings][#{i}][year]"}
                      value="false"
                    />
                    <input
                      type="checkbox"
                      name={"user[preferences][logbook_settings][#{i}][year]"}
                      value="true"
                      checked={row.year}
                      class="rounded border-zinc-300 text-zinc-900 focus:ring-zinc-900"
                    />
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>

          <div class="mt-2 flex items-center justify-between gap-6">
            <.button phx-disable-with="Saving...">
              Update
            </.button>
          </div>
        </div>
      </.form>
    </.account_settings>
    """
  end

  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    # Preload :preferences so `inputs_for @settings_form[:preferences]` can render.
    user = Accounts.preload_preferences(scope.current_user)
    preferences = Accounts.get_user_preferences(user)
    settings_changeset = Accounts.User.preferences_changeset(user, %{})

    books = Ornitho.Finder.Book.all()

    book_options =
      Enum.map(books, fn b -> {"#{b.name} (#{b.slug}/#{b.version})", "#{b.slug}/#{b.version}"} end)

    logbook_location_rows =
      build_logbook_location_rows(scope, preferences.logbook_settings)

    socket =
      socket
      |> assign(:page_title, "Preferences")
      |> assign(:user, user)
      |> assign(:preferences, preferences)
      |> assign(:settings_form, to_form(settings_changeset))
      |> assign(:book_options, book_options)
      |> assign(:logbook_location_rows, logbook_location_rows)

    {:ok, socket}
  end

  def handle_event("validate_settings", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.user
      |> Accounts.User.preferences_changeset(user_params)
      |> Map.put(:action, :validate)

    # Rebuild the logbook rows from the in-progress edits (not the saved settings)
    # so the checkboxes reflect what was just clicked; otherwise `checked={row.life}`
    # snaps back to the stored value on every change.
    logbook_settings =
      changeset
      |> Ecto.Changeset.apply_changes()
      |> edited_logbook_settings()

    {:noreply,
     socket
     |> assign(:settings_form, to_form(changeset))
     |> assign(
       :logbook_location_rows,
       build_logbook_location_rows(socket.assigns.current_scope, logbook_settings)
     )}
  end

  def handle_event("update_settings", %{"user" => user_params}, socket) do
    user = socket.assigns.user

    case Accounts.update_user_preferences(user, user_params) do
      {:ok, user} ->
        preferences = Accounts.get_user_preferences(user)
        settings_form = user |> Accounts.User.preferences_changeset(%{}) |> to_form()
        scope = %{socket.assigns.current_scope | current_user: user}

        socket =
          socket
          |> put_flash(:info, "User account updated.")
          |> assign(:current_scope, scope)
          |> assign(:user, user)
          |> assign(:preferences, preferences)
          |> assign(:settings_form, settings_form)
          |> assign(
            :logbook_location_rows,
            build_logbook_location_rows(scope, preferences.logbook_settings)
          )

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, settings_form: to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  # Reads logbook settings off the edited user's preferences assoc, which is
  # absent until the form first touches it.
  defp edited_logbook_settings(%{preferences: %{logbook_settings: settings}}), do: settings
  defp edited_logbook_settings(_user), do: []

  # Build the list of rows for the logbook settings table.
  # World + the countries/regions the user has observations in + any location
  # with an enabled setting that isn't otherwise in the list (so a deliberate
  # toggle survives even if the user currently has no observations there).
  defp build_logbook_location_rows(scope, logbook_settings) do
    existing_settings = Map.new(logbook_settings, &{&1.location_id, &1})

    offered_locations = Geo.get_locations_by_ids(Lifelist.location_ids(scope))
    offered_ids = MapSet.new(offered_locations, & &1.id)

    # Re-add a location only if it has an enabled setting and isn't already
    # offered. All-false placeholder rows (e.g. leftovers from when every
    # country was saved) are dropped.
    extra_location_ids =
      existing_settings
      |> Enum.filter(fn {id, setting} ->
        id && !MapSet.member?(offered_ids, id) && (setting.life || setting.year)
      end)
      |> Enum.map(fn {id, _setting} -> id end)

    extra_locations =
      if extra_location_ids != [] do
        Geo.get_locations_by_ids(extra_location_ids)
      else
        []
      end

    sorted_locations = sort_logbook_locations(offered_locations ++ extra_locations)

    # World row first
    world_setting = Map.get(existing_settings, nil)

    world_row = %{
      location_id: nil,
      name: "World",
      flag: nil,
      nested: false,
      life: if(world_setting, do: world_setting.life, else: false),
      year: if(world_setting, do: world_setting.year, else: false)
    }

    location_rows =
      Enum.map(sorted_locations, fn {loc, nested?} ->
        location_to_row(loc, nested?, existing_settings)
      end)

    [world_row | location_rows]
  end

  # Group child locations under their country. Returns a flat list of
  # {location, nested?} tuples so the template can render nesting explicitly
  # instead of guessing from presence of a flag.
  #
  # Top-level order: non-country tops first (alphabetical), then countries
  # (alphabetical), each country immediately followed by its children. Inside
  # each country block, subdivisions come first (alphabetical), then any other
  # sub-country locations (specials, etc.) alphabetical.
  defp sort_logbook_locations(locations) do
    {countries, others} = Enum.split_with(locations, &(&1.location_type == :country))
    country_ids = MapSet.new(countries, & &1.id)

    {children, top_level_others} =
      Enum.split_with(
        others,
        &(&1.country_id && MapSet.member?(country_ids, &1.country_id))
      )

    children_by_country = Enum.group_by(children, & &1.country_id)

    non_country_top =
      top_level_others
      |> Enum.sort_by(& &1.name_en)
      |> Enum.map(&{&1, false})

    country_blocks =
      countries
      |> Enum.sort_by(& &1.name_en)
      |> Enum.flat_map(fn country ->
        country_children =
          children_by_country
          |> Map.get(country.id, [])
          |> sort_country_children()
          |> Enum.map(&{&1, true})

        [{country, false} | country_children]
      end)

    non_country_top ++ country_blocks
  end

  # Subdivisions first (alphabetical), then everything else alphabetical.
  defp sort_country_children(children) do
    {regions, rest} = Enum.split_with(children, &(&1.location_type == :subdivision1))
    Enum.sort_by(regions, & &1.name_en) ++ Enum.sort_by(rest, & &1.name_en)
  end

  defp location_to_row(loc, nested?, existing_settings) do
    setting = Map.get(existing_settings, loc.id)

    flag =
      if loc.location_type == :country do
        case Kjogvi.Geo.Location.to_flag_emoji(loc) do
          "" -> nil
          f -> f
        end
      end

    %{
      location_id: loc.id,
      name: loc.name_en,
      flag: flag,
      nested: nested?,
      life: if(setting, do: setting.life, else: false),
      year: if(setting, do: setting.year, else: false)
    }
  end
end
