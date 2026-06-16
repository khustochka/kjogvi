defmodule KjogviWeb.Live.Accounts.ConfirmationInstructions do
  @moduledoc false

  use KjogviWeb, :live_view

  alias Kjogvi.Accounts

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <CoreComponents.header class="text-center">
        No confirmation instructions received?
        <:subtitle>We'll send a new confirmation link to your inbox</:subtitle>
      </CoreComponents.header>

      <CoreComponents.simple_form
        for={@form}
        id="resend_confirmation_form"
        phx-submit="send_instructions"
      >
        <CoreComponents.input field={@form[:email]} type="email" placeholder="Email" required />
        <:actions>
          <CoreComponents.button phx-disable-with="Sending..." class="w-full">
            Resend confirmation instructions
          </CoreComponents.button>
        </:actions>
      </CoreComponents.simple_form>

      <p class="text-center mt-4">
        <span :if={not Kjogvi.Settings.registration_disabled?()}>
          <.link href={~p"/account/register"}>Register</.link> |
        </span>
        <.link href={~p"/account/login"}>Log in</.link>
      </p>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: "user"))}
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
