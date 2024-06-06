require Kjogvi.Config

Kjogvi.Config.with_user_registration do
  defmodule KjogviWeb.UserForgotPasswordLive do
    use KjogviWeb, :live_view

    alias Kjogvi.Users

    def render(assigns) do
      ~H"""
      <div class="mx-auto max-w-sm">
        <CoreComponents.header class="text-center">
          Forgot your password?
          <:subtitle>We'll send a password reset link to your inbox</:subtitle>
        </CoreComponents.header>

        <CoreComponents.simple_form for={@form} id="reset_password_form" phx-submit="send_email">
          <CoreComponents.input field={@form[:email]} type="email" placeholder="Email" required />
          <:actions>
            <CoreComponents.button phx-disable-with="Sending..." class="w-full">
              Send password reset instructions
            </CoreComponents.button>
          </:actions>
        </CoreComponents.simple_form>
        <p class="text-center text-sm mt-4">
          <.link href={~p"/users/register"}>Register</.link>
          | <.link href={~p"/users/log_in"}>Log in</.link>
        </p>
      </div>
      """
    end

    def mount(_params, _session, socket) do
      {:ok, assign(socket, form: to_form(%{}, as: "user"))}
    end

    def handle_event("send_email", %{"user" => %{"email" => email}}, socket) do
      if user = Users.get_user_by_email(email) do
        Users.deliver_user_reset_password_instructions(
          user,
          &url(~p"/users/reset_password/#{&1}")
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
end
