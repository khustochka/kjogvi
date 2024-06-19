defmodule KjogviWeb.UserLoginLive do
  use KjogviWeb, :live_view

  require Kjogvi.Config

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <CoreComponents.header class="text-center">
        Log in to account
        <:subtitle>
          <%= Kjogvi.Config.with_user_registration do %>
            Don't have an account?
            <.link navigate={~p"/users/register"} class="font-semibold text-brand hover:underline">
              Sign up
            </.link>
            for an account now.
          <% end %>
        </:subtitle>
      </CoreComponents.header>

      <CoreComponents.simple_form
        for={@form}
        id="login_form"
        action={~p"/users/log_in"}
        phx-update="ignore"
      >
        <CoreComponents.input field={@form[:email]} type="email" label="Email" required />
        <CoreComponents.input field={@form[:password]} type="password" label="Password" required />

        <:actions>
          <CoreComponents.input field={@form[:remember_me]} type="checkbox" label="Keep me logged in" />
          <%= Kjogvi.Config.with_user_registration do %>
            <.link href={~p"/users/reset_password"} class="text-sm font-semibold">
              Forgot your password?
            </.link>
          <% end %>
        </:actions>
        <:actions>
          <CoreComponents.button phx-disable-with="Signing in..." class="w-full">
            Log in <span aria-hidden="true">→</span>
          </CoreComponents.button>
        </:actions>
      </CoreComponents.simple_form>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")
    {:ok, assign(socket, form: form), temporary_assigns: [form: form]}
  end
end
