defmodule KjogviWeb.Live.Accounts.ForgotPassword do
  @moduledoc false

  use KjogviWeb, :live_view

  alias KjogviWeb.LoginRegistrationComponents

  alias Kjogvi.Accounts

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <LoginRegistrationComponents.header>
        Forgot your password?
        <:subheader>We'll send a password reset link to your inbox</:subheader>
      </LoginRegistrationComponents.header>

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
      :let={f}
      for={@form}
      id="reset-password-form"
      phx-submit="send_email"
      class="mx-auto max-w-sm mt-8 space-y-4"
    >
      <LoginRegistrationComponents.email_input
        field={f[:email]}
        label="Email"
        autocomplete="username"
        spellcheck="false"
        required
      />
      <div class="text-center">
        <CoreComponents.button phx-disable-with="Sending..." class="w-full py-4 text-xl font-header">
          Send password reset instructions
        </CoreComponents.button>
      </div>
    </.form>
    """
  end

  def mount(_params, _session, socket) do
    if Kjogvi.Settings.forgot_reset_password_disabled?() do
      {:ok, assign(socket, forgot_reset_password_disabled: true)}
    else
      {:ok, assign(socket, forgot_reset_password_disabled: false, form: to_form(%{}, as: "user"))}
    end
  end

  # Never send reset instructions once the flow is disabled, even if a client submits.
  def handle_event(
        "send_email",
        _params,
        %{assigns: %{forgot_reset_password_disabled: true}} = socket
      ) do
    {:noreply, socket}
  end

  def handle_event("send_email", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_reset_password_instructions(
        user,
        &url(~p"/account/reset-password/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions to reset your password shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/")}
  end
end
