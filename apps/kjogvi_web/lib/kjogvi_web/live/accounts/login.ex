defmodule KjogviWeb.Live.Accounts.Login do
  @moduledoc false

  use KjogviWeb, :live_view

  alias KjogviWeb.LoginRegistrationComponents

  def render(assigns) do
    ~H"""
    <div class="mx-auto lg:max-w-lg max-w-md">
      <LoginRegistrationComponents.header>
        Log into your account
        <:subheader :if={not Kjogvi.Settings.registration_disabled?()}>
          Don't have an account?
          <.link
            navigate={~p"/account/register"}
            class="text-forest-500 hover:underline"
          >Sign up</.link>
          now!
        </:subheader>
      </LoginRegistrationComponents.header>

      <.form
        :let={f}
        for={@form}
        id="login_form"
        action={~p"/account/login"}
        phx-update="ignore"
        class="mx-auto max-w-sm mt-8 space-y-4"
      >
        <LoginRegistrationComponents.email_input
          field={f[:email]}
          label="Email"
          autocomplete="username"
          spellcheck="false"
          required
        />
        <LoginRegistrationComponents.password_input
          field={f[:password]}
          label="Password"
          autocomplete="current-password"
          spellcheck="false"
          required
        />

        <div class="mt-2 flex items-center justify-between gap-6">
          <CoreComponents.input
            field={f[:remember_me]}
            type="checkbox"
            label="Keep me logged in"
          />

          <.link
            :if={not Kjogvi.Settings.forgot_reset_password_disabled?()}
            href={~p"/account/reset-password"}
            class="text-sm font-medium"
          >
            Forgot your password?
          </.link>
        </div>
        <div class="text-center">
          <CoreComponents.button class="w-1/2 py-4 text-xl font-header" phx-disable-with>
            Log in
          </CoreComponents.button>
        </div>
      </.form>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")

    {:ok,
     socket
     |> assign(page_title: "Log into your account")
     |> assign(form: form)}
  end
end
