defmodule KjogviWeb.Live.Accounts.Registration do
  @moduledoc false

  use KjogviWeb, :live_view

  alias Kjogvi.Accounts
  alias Kjogvi.Accounts.User

  def render(%{registration_disabled: true} = assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <CoreComponents.header class="text-center">
        Register for an account
        <:subtitle>
          Already registered?
          <.link navigate={~p"/account/login"} class="font-semibold text-brand hover:underline">
            Log in
          </.link>
          to your account now.
        </:subtitle>
      </CoreComponents.header>

      <div
        role="alert"
        class="mt-6 flex items-start gap-3 rounded-lg bg-amber-50 p-4 text-sm text-amber-800 ring-1 ring-amber-300"
      >
        <.icon name="hero-exclamation-triangle" class="mt-0.5 h-5 w-5 shrink-0 text-amber-500" />
        <p>Registration is temporarily disabled. Please check back later.</p>
      </div>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <CoreComponents.header class="text-center">
        Register for an account
        <:subtitle>
          Already registered?
          <.link navigate={~p"/account/login"} class="font-semibold text-brand hover:underline">
            Log in
          </.link>
          to your account now.
        </:subtitle>
      </CoreComponents.header>

      <CoreComponents.simple_form
        for={@form}
        id="registration_form"
        phx-submit="save"
        phx-change="validate"
        phx-trigger-action={@trigger_submit}
        action={~p"/account/register"}
        method="post"
      >
        <CoreComponents.input
          field={@form[:email]}
          type="email"
          label="Email"
          phx-blur="validate_email"
          phx-debounce="500"
          autocomplete="username"
          spellcheck="false"
          required
        />
        <CoreComponents.input
          field={@form[:password]}
          type="password"
          label="Password"
          autocomplete="new-password"
          spellcheck="false"
          required
        >
          <:hint>Use at least 12 characters.</:hint>
        </CoreComponents.input>

        <:actions>
          <CoreComponents.button phx-disable-with="Creating account..." class="w-full">
            Create an account
          </CoreComponents.button>
        </:actions>
      </CoreComponents.simple_form>
    </div>
    """
  end

  def mount(_params, _session, socket) do
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
