defmodule KjogviWeb.Live.My.Account.Settings do
  @moduledoc false

  use KjogviWeb, :live_view

  alias Kjogvi.Users
  alias Kjogvi.Geo

  def render(assigns) do
    ~H"""
    <CoreComponents.header class="text-center">
      Account Settings
      <:subtitle>Manage your account email address and password settings</:subtitle>
    </CoreComponents.header>

    <div class="divide-y divide-zinc-200">
      <div>
        <CoreComponents.simple_form
          for={@email_form}
          id="email_form"
          phx-submit="update_email"
          phx-change="validate_email"
          class="mb-6"
        >
          <CoreComponents.input field={@email_form[:email]} type="email" label="Email" required />
          <.input
            field={@email_form[:current_password]}
            name="current_password"
            id="current_password_for_email"
            type="password"
            label="Current password"
            value={@email_form_current_password}
            required
          />
          <:actions>
            <CoreComponents.button phx-disable-with="Changing...">Change Email</CoreComponents.button>
          </:actions>
        </CoreComponents.simple_form>
      </div>
      <div class="mb-6">
        <CoreComponents.simple_form
          for={@password_form}
          id="password_form"
          action={~p"/users/log_in?_action=password_updated"}
          method="post"
          phx-change="validate_password"
          phx-submit="update_password"
          phx-trigger-action={@trigger_submit}
          class="mb-6"
        >
          <input
            name={@password_form[:email].name}
            type="hidden"
            id="hidden_user_email"
            value={@current_email}
          />
          <.input
            field={@password_form[:current_password]}
            name="current_password"
            type="password"
            label="Current password"
            id="current_password_for_password"
            value={@current_password}
            required
          />
          <.input field={@password_form[:password]} type="password" label="New password" required />
          <.input
            field={@password_form[:password_confirmation]}
            type="password"
            label="Confirm new password"
          />
          <:actions>
            <CoreComponents.button phx-disable-with="Changing...">
              Change Password
            </CoreComponents.button>
          </:actions>
        </CoreComponents.simple_form>
      </div>

      <div>
        <.h2>
          User settings
        </.h2>

        <div>
          <CoreComponents.simple_form
            for={@settings_form}
            id="settings_form"
            action={~p"/my/account/settings"}
            method="post"
          >
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
            <.inputs_for :let={settings_form_extras} field={@settings_form[:extras]}>
              <.inputs_for :let={ebird_form} field={settings_form_extras[:ebird]}>
                <CoreComponents.input
                  field={ebird_form[:username]}
                  label="Username"
                  id="ebird_username"
                  value={@current_scope.user.extras.ebird.username}
                />
                <div>
                  <.input
                    field={ebird_form[:password]}
                    type="password"
                    label="Password"
                    id="ebird_password"
                    value={@current_scope.user.extras.ebird.password}
                  />
                </div>
              </.inputs_for>
            </.inputs_for>
            <h3
              id="log-settings"
              class="text-xl font-header font-semibold leading-none text-zinc-500 mt-6 scroll-mt-4"
            >
              Log settings
            </h3>
            <p class="text-sm text-zinc-500 mb-2">
              Choose which lists to include in the recent additions log.
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
                <%= for {row, i} <- Enum.with_index(@log_location_rows) do %>
                  <tr class="border-b border-zinc-300">
                    <td class="py-2">
                      <input
                        type="hidden"
                        name={"user[extras][log_settings][#{i}][location_id]"}
                        value={row.location_id || ""}
                      />
                      <span :if={row.location_id == nil} class="inline-flex items-center gap-1">
                        <.icon name="fa-solid-earth-americas" class="h-4 w-4 text-gray-500" /> {row.name}
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
                        name={"user[extras][log_settings][#{i}][life]"}
                        value="false"
                      />
                      <input
                        type="checkbox"
                        name={"user[extras][log_settings][#{i}][life]"}
                        value="true"
                        checked={row.life}
                        class="rounded border-zinc-300 text-zinc-900 focus:ring-zinc-900"
                      />
                    </td>
                    <td class="text-center py-2">
                      <input
                        type="hidden"
                        name={"user[extras][log_settings][#{i}][year]"}
                        value="false"
                      />
                      <input
                        type="checkbox"
                        name={"user[extras][log_settings][#{i}][year]"}
                        value="true"
                        checked={row.year}
                        class="rounded border-zinc-300 text-zinc-900 focus:ring-zinc-900"
                      />
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>

            <:actions>
              <CoreComponents.button phx-disable-with="Saving...">
                Update
              </CoreComponents.button>
            </:actions>
          </CoreComponents.simple_form>
        </div>
      </div>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Users.update_user_email(socket.assigns.current_scope.user, token) do
        :ok ->
          put_flash(socket, :info, "Email changed successfully.")

        :error ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/my/account/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    email_changeset = Users.change_user_email(user)
    password_changeset = Users.change_user_password(user)
    settings_changeset = Kjogvi.Users.User.settings_changeset(user, %{})

    books = Ornitho.Finder.Book.all()

    book_options =
      Enum.map(books, fn b -> {"#{b.name} (#{b.slug}/#{b.version})", "#{b.slug}/#{b.version}"} end)

    log_location_rows = build_log_location_rows(user)

    socket =
      socket
      |> assign(:current_password, nil)
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)
      |> assign(:settings_form, to_form(settings_changeset))
      |> assign(:ebird_password_show, false)
      |> assign(:book_options, book_options)
      |> assign(:log_location_rows, log_location_rows)

    {:ok, socket}
  end

  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Users.change_user_email(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form, email_form_current_password: password)}
  end

  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_scope.user

    case Users.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Users.deliver_user_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/my/account/settings/confirm_email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info) |> assign(email_form_current_password: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_form, to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Users.change_user_password(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_scope.user

    case Users.update_user_password(user, password, user_params) do
      {:ok, user} ->
        password_form =
          user
          |> Users.change_user_password(user_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end

  # Build the list of rows for the log settings table.
  # World + all countries/regions/lifelist filters + any locations that already
  # have settings but aren't otherwise in the list (e.g. private ones).
  defp build_log_location_rows(user) do
    log_settings = user.extras.log_settings
    existing_settings = Map.new(log_settings, &{&1.location_id, &1})

    offered_locations = Geo.get_log_settings_locations()
    offered_ids = MapSet.new(offered_locations, & &1.id)

    # Locations that already have settings but aren't in the offered set
    # (e.g. private locations, or anything outside countries/regions/lifelist filters).
    extra_location_ids =
      existing_settings
      |> Map.keys()
      |> Enum.filter(&(&1 && !MapSet.member?(offered_ids, &1)))

    extra_locations =
      if extra_location_ids != [] do
        Geo.get_locations_by_ids(extra_location_ids)
      else
        []
      end

    sorted_locations = sort_log_locations(offered_locations ++ extra_locations)

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
  # Top-level order: continents/specials first (alphabetical), then countries
  # (alphabetical), each country immediately followed by its children. Inside
  # each country block, regions come first (alphabetical), then any other
  # sub-country locations (specials, etc.) alphabetical.
  defp sort_log_locations(locations) do
    {countries, others} = Enum.split_with(locations, &(&1.location_type == "country"))
    country_ids = MapSet.new(countries, & &1.id)

    {children, top_level_others} =
      Enum.split_with(
        others,
        &(&1.cached_country_id && MapSet.member?(country_ids, &1.cached_country_id))
      )

    children_by_country = Enum.group_by(children, & &1.cached_country_id)

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

  # Regions first (alphabetical), then everything else alphabetical.
  defp sort_country_children(children) do
    {regions, rest} = Enum.split_with(children, &(&1.location_type == "region"))
    Enum.sort_by(regions, & &1.name_en) ++ Enum.sort_by(rest, & &1.name_en)
  end

  defp location_to_row(loc, nested?, existing_settings) do
    setting = Map.get(existing_settings, loc.id)

    flag =
      if loc.location_type == "country" do
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
