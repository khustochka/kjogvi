defmodule KjogviWeb.Live.Accounts.Confirmation do
  @moduledoc false

  use KjogviWeb, :live_view

  alias Kjogvi.Accounts

  def render(%{live_action: :edit} = assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <CoreComponents.header class="text-center">Confirm Account</CoreComponents.header>

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
    <CoreComponents.simple_form for={@form} id="confirmation_form" phx-submit="confirm_account">
      <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
      <:actions>
        <CoreComponents.button phx-disable-with="Confirming..." class="w-full">
          Confirm my account
        </CoreComponents.button>
      </:actions>
    </CoreComponents.simple_form>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    if Kjogvi.Settings.confirmation_disabled?() do
      {:ok, assign(socket, confirmation_disabled: true, form: nil)}
    else
      form = to_form(%{"token" => token}, as: "user")

      {:ok, assign(socket, confirmation_disabled: false, form: form),
       temporary_assigns: [form: nil]}
    end
  end

  # Never confirm an account once the flow is disabled, even if a client submits.
  def handle_event(
        "confirm_account",
        _params,
        %{assigns: %{confirmation_disabled: true}} = socket
      ) do
    {:noreply, socket}
  end

  # Do not log in the user after confirmation to avoid a
  # leaked token giving the user access to the account.
  def handle_event("confirm_account", %{"user" => %{"token" => token}}, socket) do
    case Accounts.confirm_user(token) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "User confirmed successfully.")
         |> redirect(to: ~p"/")}

      :error ->
        # If there is a current user and the account was already confirmed,
        # then odds are that the confirmation link was already visited, either
        # by some automation or by the user themselves, so we redirect without
        # a warning message.
        case socket.assigns do
          %{current_scope: %{current_user: %{confirmed_at: confirmed_at}}}
          when not is_nil(confirmed_at) ->
            {:noreply, redirect(socket, to: ~p"/")}

          %{} ->
            {:noreply,
             socket
             |> put_flash(:error, "User confirmation link is invalid or it has expired.")
             |> redirect(to: ~p"/")}
        end
    end
  end
end
