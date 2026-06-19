defmodule KjogviWeb.Live.Accounts.ConfirmationInstructions do
  @moduledoc false

  use KjogviWeb, :live_view

  alias KjogviWeb.LoginRegistrationComponents

  alias Kjogvi.Accounts

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <LoginRegistrationComponents.header>
        No confirmation instructions received?
        <:subheader>We'll send a new confirmation link to your inbox</:subheader>
      </LoginRegistrationComponents.header>

      {render_form(assigns)}

      <p class="text-center mt-4">
        <span :if={not Kjogvi.Settings.registration_disabled?()}>
          <.link href={~p"/account/register"}>Register</.link> |
        </span>
        <.link href={~p"/account/login"}>Log in</.link>
      </p>
    </div>
    """
  end

  defp render_form(%{confirmation_disabled: true} = assigns) do
    ~H"""
    <div
      role="alert"
      class="mt-6 flex items-start gap-3 rounded-lg bg-amber-50 p-4 text-sm text-amber-800 ring-1 ring-amber-300"
    >
      <.icon name="hero-exclamation-triangle" class="mt-0.5 h-5 w-5 shrink-0 text-amber-500" />
      <p>Account confirmation is temporarily disabled. Please check back later.</p>
    </div>
    """
  end

  defp render_form(assigns) do
    ~H"""
    <.form
      for={@form}
      id="resend_confirmation_form"
      phx-submit="send_instructions"
      class="mx-auto max-w-sm mt-8 space-y-4"
    >
      <LoginRegistrationComponents.email_input
        field={@form[:email]}
        label="Email"
        autocomplete="username"
        spellcheck="false"
        required
      />
      <div class="text-center">
        <.button phx-disable-with="Sending..." class="w-full py-4 text-xl font-header">
          Resend confirmation instructions
        </.button>
      </div>
    </.form>
    """
  end

  def mount(_params, _session, socket) do
    if Kjogvi.Settings.confirmation_disabled?() do
      {:ok, assign(socket, confirmation_disabled: true, form: nil)}
    else
      {:ok, assign(socket, confirmation_disabled: false, form: to_form(%{}, as: "user"))}
    end
  end

  # Never send confirmation instructions once the flow is disabled.
  def handle_event(
        "send_instructions",
        _params,
        %{assigns: %{confirmation_disabled: true}} = socket
      ) do
    {:noreply, socket}
  end

  def handle_event("send_instructions", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_confirmation_instructions(
        user,
        &url(~p"/account/confirm/#{&1}")
      )
    end

    info =
      "If your email is in our system and it has not been confirmed yet, you will receive an email with instructions shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/")}
  end
end
