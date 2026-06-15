defmodule KjogviWeb.Accounts.UserRegistration do
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
          <.link navigate={~p"/account/log_in"} class="font-semibold text-brand hover:underline">
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
          <.link navigate={~p"/account/log_in"} class="font-semibold text-brand hover:underline">
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
        action={~p"/account/log_in?_action=registered"}
        method="post"
      >
        <CoreComponents.error :if={@check_errors}>
          Oops, something went wrong! Please check the errors below.
        </CoreComponents.error>

        <CoreComponents.input field={@form[:email]} type="email" label="Email" required />
        <CoreComponents.input field={@form[:password]} type="password" label="Password" required />

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
      changeset = Accounts.change_user_registration(%User{})

      socket =
        socket
        |> assign(registration_disabled: false, trigger_submit: false, check_errors: false)
        |> assign_form(changeset)

      {:ok, socket, temporary_assigns: [form: nil]}
    end
  end

  # Defense in depth: even if a client submits the form (e.g. the kill switch
  # flipped while mounted, or a crafted event), never create a user.
  def handle_event("save", _params, %{assigns: %{registration_disabled: true}} = socket) do
    {:noreply, socket}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(put_suggested_nickname(user_params)) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &url(~p"/account/confirm/#{&1}")
          )

        changeset = Accounts.change_user_registration(user)
        {:noreply, socket |> assign(trigger_submit: true) |> assign_form(changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, put_suggested_nickname(user_params))
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  # The nickname is no longer entered on the form; derive it from the email so
  # the changeset stays valid and the user gets a sensible default.
  defp put_suggested_nickname(%{"email" => email} = user_params)
       when is_binary(email) and email != "" do
    Map.put(user_params, "nickname", Accounts.suggest_nickname_from_email(email))
  end

  defp put_suggested_nickname(user_params), do: user_params

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
