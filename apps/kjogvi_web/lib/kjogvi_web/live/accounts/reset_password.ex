defmodule KjogviWeb.Live.Accounts.ResetPassword do
  @moduledoc false

  use KjogviWeb, :live_view

  alias Kjogvi.Accounts

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <CoreComponents.header class="text-center">Reset Password</CoreComponents.header>

      {render_form(assigns)}

      <p class="text-center text-sm mt-4">
        <span :if={not Kjogvi.Settings.registration_disabled?()}>
          <.link href={~p"/account/register"}>Register</.link> |
        </span>
        <.link href={~p"/account/login"}>Log in</.link>
      </p>
    </div>
    """
  end

  defp render_form(%{forgot_reset_password_disabled: true} = assigns) do
    ~H"""
    <div
      role="alert"
      class="mt-6 flex items-start gap-3 rounded-lg bg-amber-50 p-4 text-sm text-amber-800 ring-1 ring-amber-300"
    >
      <.icon name="hero-exclamation-triangle" class="mt-0.5 h-5 w-5 shrink-0 text-amber-500" />
      <p>Password reset is temporarily disabled. Please check back later.</p>
    </div>
    """
  end

  defp render_form(assigns) do
    ~H"""
    <.form
      for={@form}
      id="reset-password-form"
      phx-submit="reset-password"
      phx-change="validate"
    >
      <div class="mt-8 space-y-8 bg-white">
        <CoreComponents.error :if={@form.errors != []}>
          Oops, something went wrong! Please check the errors below.
        </CoreComponents.error>

        <CoreComponents.input field={@form[:password]} type="password" label="New password" required />
        <CoreComponents.input
          field={@form[:password_confirmation]}
          type="password"
          label="Confirm new password"
          required
        />
        <div class="mt-2 flex items-center justify-between gap-6">
          <CoreComponents.button phx-disable-with="Resetting..." class="w-full">
            Reset Password
          </CoreComponents.button>
        </div>
      </div>
    </.form>
    """
  end

  def mount(params, _session, socket) do
    if Kjogvi.Settings.forgot_reset_password_disabled?() do
      {:ok, assign(socket, forgot_reset_password_disabled: true)}
    else
      socket =
        socket
        |> assign(forgot_reset_password_disabled: false)
        |> assign_user_and_token(params)

      form_source =
        case socket.assigns do
          %{user: user} ->
            Accounts.change_user_password(user)

          _ ->
            %{}
        end

      {:ok, assign_form(socket, form_source), temporary_assigns: [form: nil]}
    end
  end

  # Never reset a password once the flow is disabled, even if a client submits.
  def handle_event(
        "reset-password",
        _params,
        %{assigns: %{forgot_reset_password_disabled: true}} = socket
      ) do
    {:noreply, socket}
  end

  # Do not log in the user after reset password to avoid a
  # leaked token giving the user access to the account.
  def handle_event("reset-password", %{"user" => user_params}, socket) do
    case Accounts.reset_user_password(socket.assigns.user, user_params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Password reset successfully.")
         |> redirect(to: ~p"/account/login")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :insert))}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_password(socket.assigns.user, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_user_and_token(socket, %{"token" => token}) do
    if user = Accounts.get_user_by_reset_password_token(token) do
      assign(socket, user: user, token: token)
    else
      socket
      |> put_flash(:error, "Reset password link is invalid or it has expired.")
      |> redirect(to: ~p"/")
    end
  end

  defp assign_form(socket, %{} = source) do
    assign(socket, :form, to_form(source, as: "user"))
  end
end
