defmodule KjogviWeb.Live.My.Account.Settings do
  @moduledoc false

  use KjogviWeb, :live_view

  alias Kjogvi.Users

  def render(assigns) do
    ~H"""
    <CoreComponents.header class="text-center">
      Account Settings
      <:subtitle>Manage your account email address and password settings</:subtitle>
    </CoreComponents.header>

    <div class="space-y-12 divide-y">
      <div>
        <CoreComponents.simple_form
          for={@email_form}
          id="email_form"
          phx-submit="update_email"
          phx-change="validate_email"
        >
          <CoreComponents.input field={@email_form[:email]} type="email" label="Email" required />
          <CoreComponents.input
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
      <div>
        <CoreComponents.simple_form
          for={@password_form}
          id="password_form"
          action={~p"/users/log_in?_action=password_updated"}
          method="post"
          phx-change="validate_password"
          phx-submit="update_password"
          phx-trigger-action={@trigger_submit}
        >
          <input
            name={@password_form[:email].name}
            type="hidden"
            id="hidden_user_email"
            value={@current_email}
          />
          <CoreComponents.input
            field={@password_form[:current_password]}
            name="current_password"
            type="password"
            label="Current password"
            id="current_password_for_password"
            value={@current_password}
            required
          />
          <CoreComponents.input
            field={@password_form[:password]}
            type="password"
            label="New password"
            required
          />
          <CoreComponents.input
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
        <h3 class="text-xl font-header font-semibold leading-none text-zinc-500 mt-6">
          Ebird settings
        </h3>

        <div>
          <CoreComponents.simple_form
            for={@settings_form}
            id="settings_form"
            action={~p"/my/account/settings"}
            method="post"
          >
            <.inputs_for :let={settings_form} field={@settings_form[:extras]}>
              <.inputs_for :let={ebird_form} field={settings_form[:ebird]}>
                <CoreComponents.input
                  field={ebird_form[:username]}
                  label="Username"
                  id="ebird_username"
                  value={@current_scope.user.extras.ebird.username}
                />
                <CoreComponents.input
                  field={ebird_form[:password]}
                  type="password"
                  label="Password"
                  id="ebird_password"
                  value={@current_scope.user.extras.ebird.password}
                />
              </.inputs_for>
            </.inputs_for>
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

    socket =
      socket
      |> assign(:current_password, nil)
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)
      |> assign(:settings_form, to_form(settings_changeset))

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
end
