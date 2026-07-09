defmodule KjogviWeb.Live.My.Settings.Profile do
  @moduledoc false

  use KjogviWeb, :live_view

  alias Kjogvi.Accounts
  alias Kjogvi.Geo

  def render(assigns) do
    ~H"""
    <.h1>Account Settings</.h1>

    <.account_settings active={:profile}>
      <.h2>Profile</.h2>

      <.form
        for={@settings_form}
        id="settings_form"
        phx-change="validate_settings"
        phx-submit="update_settings"
      >
        <div class="mt-8 space-y-8 bg-white">
          <CoreComponents.input
            field={@settings_form[:nickname]}
            type="text"
            label="Nickname"
            required
          >
            <:hint>3–20 characters: lowercase letters, digits, hyphens and underscores.</:hint>
          </CoreComponents.input>

          <CoreComponents.input
            field={@settings_form[:display_name]}
            type="text"
            label="Display name"
          >
            <:hint>Up to 50 characters: letters, spaces and common punctuation.</:hint>
          </CoreComponents.input>

          <.inputs_for :let={profile_form} field={@settings_form[:profile]}>
            <CoreComponents.input
              field={profile_form[:about]}
              type="textarea"
              label="About"
              rows="4"
            >
              <:hint>A short description of yourself. Up to 2000 characters.</:hint>
            </CoreComponents.input>

            <CoreComponents.input
              field={profile_form[:country]}
              type="select"
              label="Country"
              options={@country_options}
              prompt="Select country..."
            />

            <CoreComponents.input
              field={profile_form[:ebird_profile_url]}
              type="url"
              label="eBird profile URL"
            >
              <:hint>Link to your public eBird profile.</:hint>
            </CoreComponents.input>

            <CoreComponents.input
              field={profile_form[:website_url]}
              type="url"
              label="Website URL"
            />
          </.inputs_for>

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

  def mount(_params, _session, %{assigns: %{live_action: :redirect}} = socket) do
    {:ok, push_navigate(socket, to: ~p"/my/settings/profile")}
  end

  def mount(_params, _session, socket) do
    # Preload :profile so `inputs_for @settings_form[:profile]` can render.
    user = Accounts.preload_profile(socket.assigns.current_scope.current_user)
    settings_changeset = Accounts.User.profile_settings_changeset(user, %{})

    socket =
      socket
      |> assign(:page_title, "Profile")
      |> assign(:user, user)
      |> assign(:country_options, country_options())
      |> assign(:settings_form, to_form(settings_changeset))

    {:ok, socket}
  end

  def handle_event("validate_settings", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.user
      |> Accounts.User.profile_settings_changeset(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :settings_form, to_form(changeset))}
  end

  def handle_event("update_settings", %{"user" => user_params}, socket) do
    case Accounts.update_user_profile_settings(socket.assigns.user, user_params) do
      {:ok, user} ->
        settings_form =
          user
          |> Accounts.User.profile_settings_changeset(%{})
          |> to_form()

        scope = %{socket.assigns.current_scope | current_user: user}

        socket =
          socket
          |> put_flash(:info, "User account updated.")
          |> assign(:current_scope, scope)
          |> assign(:user, user)
          |> assign(:settings_form, settings_form)

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, settings_form: to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  defp country_options do
    Enum.map(Geo.list_common_countries(), &{&1.name_en, &1.iso_code})
  end
end
