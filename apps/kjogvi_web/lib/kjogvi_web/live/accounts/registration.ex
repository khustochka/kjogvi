defmodule KjogviWeb.Live.Accounts.Registration do
  @moduledoc false

  use KjogviWeb, :live_view

  alias KjogviWeb.LoginRegistrationComponents

  alias Kjogvi.Accounts
  alias Kjogvi.Accounts.User

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <LoginRegistrationComponents.header header_class="sm:mb-3 mb-2 sm:text-4xl text-2xl">
        Sign up for an account
        <:subheader>
          Already registered?
          <.link navigate={~p"/account/login"} class="text-forest-500 hover:underline">Log in</.link>
          now!
        </:subheader>
      </LoginRegistrationComponents.header>

      {render_form(assigns)}
    </div>
    """
  end

  defp render_form(%{registration_disabled: true} = assigns) do
    ~H"""
    <div
      role="alert"
      class="mt-6 flex items-start gap-3 rounded-lg bg-amber-50 p-4 text-sm text-amber-800 ring-1 ring-amber-300"
    >
      <.icon name="hero-exclamation-triangle" class="mt-0.5 h-5 w-5 shrink-0 text-amber-500" />
      <p>Registration is temporarily disabled. Please check back later.</p>
    </div>
    """
  end

  defp render_form(assigns) do
    ~H"""
    <.form
      :let={f}
      for={@form}
      id="registration_form"
      phx-submit="save"
      phx-change="validate"
      phx-trigger-action={@trigger_submit}
      action={~p"/account/register"}
      method="post"
      class="mx-auto max-w-sm mt-8 space-y-4"
    >
      <LoginRegistrationComponents.email_input
        field={f[:email]}
        label="Email"
        phx-blur="validate_email"
        phx-debounce="500"
        autocomplete="username"
        spellcheck="false"
        show_required
        required
      />
      <LoginRegistrationComponents.password_input
        field={f[:password]}
        label="Password"
        autocomplete="new-password"
        spellcheck="false"
        show_required
        hint_as_error
        required
      >
        <:hint>Should be 12–72 characters.</:hint>
      </LoginRegistrationComponents.password_input>

      <div class="text-center">
        <.button
          phx-disable-with
          class="w-1/2 py-4 text-xl font-header"
        >
          Submit
        </.button>
      </div>
    </.form>
    """
  end

  def mount(_params, _session, socket) do
    socket = assign(socket, page_title: "Sign up an account")

    if Kjogvi.Settings.registration_disabled?() do
      {:ok, assign(socket, registration_disabled: true)}
    else
      changeset = Accounts.change_user_registration_validation(%User{})

      socket =
        socket
        |> assign(registration_disabled: false, trigger_submit: false, validate_email: false)
        |> assign_form(changeset)

      {:ok, socket, temporary_assigns: [form: nil]}
    end
  end

  # Never create a user once registration is disabled, even if a client submits.
  def handle_event("save", _params, %{assigns: %{registration_disabled: true}} = socket) do
    {:noreply, socket}
  end

  # On a valid form, POST to UserRegistrationController via trigger_submit;
  # otherwise render the errors. Email uniqueness is only checked here, not on
  # every keystroke.
  def handle_event("save", %{"user" => user_params}, socket) do
    changeset =
      Accounts.change_user_registration_validation(%User{}, user_params, validate_email: true)

    if changeset.valid? do
      {:noreply, assign(socket, trigger_submit: true)}
    else
      {:noreply, assign_form(socket, Map.put(changeset, :action, :insert))}
    end
  end

  # Email format and uniqueness stay off until the field is blurred (see
  # "validate_email"), so an in-progress email isn't flagged while typing.
  def handle_event("validate", %{"user" => user_params}, socket) do
    {:noreply, validate(socket, user_params)}
  end

  # Blurring the email field opts it into format and uniqueness validation from
  # now on, so a malformed or already-taken email surfaces before submit.
  def handle_event("validate_email", %{"value" => email}, socket) do
    socket = assign(socket, validate_email: true)
    {:noreply, validate(socket, %{"email" => email})}
  end

  defp validate(socket, user_params) do
    validate_email = socket.assigns.validate_email

    changeset =
      Accounts.change_user_registration_validation(%User{}, user_params,
        validate_email_format: validate_email,
        validate_email: validate_email
      )

    assign_form(socket, Map.put(changeset, :action, :validate))
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, form: to_form(changeset, as: "user"))
  end
end
