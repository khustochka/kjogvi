defmodule KjogviWeb.Live.Admin.Users.Settings do
  @moduledoc """
  Admin page for the per-user settings (`Kjogvi.Settings.User`) of a single
  user: today just the login kill switch.

  Like the site settings page, the flag is stored negatively
  (`login_disabled`) but presented positively — the page states whether *login*
  is enabled and labels the button with the action the click performs. Toggling
  goes through `Accounts.disable_user_login/1` / `enable_user_login/1`, so
  disabling also ends the user's active sessions.
  """

  use KjogviWeb, :live_view

  alias Kjogvi.Accounts
  alias Kjogvi.Accounts.User

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = Accounts.get_user!(id)

    {:ok,
     socket
     |> assign(:page_title, "#{User.display_name(user)} — Settings")
     |> assign(:user, user)
     |> assign_login_state()}
  end

  @impl true
  def handle_event("toggle_login", _params, socket) do
    user = socket.assigns.user

    {verb, _} =
      if socket.assigns.login_enabled do
        {"disabled", Accounts.disable_user_login(user)}
      else
        {"enabled", Accounts.enable_user_login(user)}
      end

    {:noreply,
     socket
     |> put_flash(:info, "Login #{verb} for #{User.display_name(user)}.")
     |> assign_login_state()}
  end

  defp assign_login_state(socket) do
    assign(socket, :login_enabled, not Accounts.login_disabled?(socket.assigns.user))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.link navigate={~p"/admin/users"} class="text-sm text-forest-600 hover:underline">
        ← Back to users
      </.link>

      <.header_with_subheader>
        User Settings
        <:subheader>{@user.nickname}</:subheader>
      </.header_with_subheader>

      <section id="access-flags" class="border border-slate-300 rounded-lg p-6">
        <.h2 class="mb-4!">Access</.h2>

        <p class="text-sm text-slate-700 mb-4">
          Bar this user from signing in. Disabling ends their active sessions immediately.
        </p>

        <div class="flex items-center justify-between gap-4">
          <.h3
            id="login-state"
            class={[
              "mb-0!",
              if(@login_enabled, do: "text-emerald-700!", else: "text-rose-700!")
            ]}
          >
            Login {if @login_enabled, do: "enabled", else: "disabled"}
          </.h3>

          <.button
            id="toggle-login"
            phx-click="toggle_login"
            variant={if @login_enabled, do: "danger", else: "primary"}
            class="shrink-0"
          >
            {if @login_enabled, do: "Disable login", else: "Enable login"}
          </.button>
        </div>
      </section>
    </div>
    """
  end
end
