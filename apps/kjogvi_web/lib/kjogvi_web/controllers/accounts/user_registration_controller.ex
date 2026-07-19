defmodule KjogviWeb.Accounts.UserRegistrationController do
  use KjogviWeb, :controller

  alias Kjogvi.Accounts
  alias KjogviWeb.UserAuth

  # Plain controller action so registration also works without JS.
  def create(conn, %{"user" => user_params}) do
    if Kjogvi.Settings.registration_disabled?() do
      conn
      |> put_flash(:error, "Registration is temporarily disabled.")
      |> redirect(to: ~p"/account/register")
    else
      register(conn, user_params)
    end
  end

  defp register(conn, user_params) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        unless Kjogvi.Settings.email_confirmation_disabled?() do
          {:ok, _} =
            Accounts.deliver_user_confirmation_instructions(
              user,
              &url(~p"/account/confirm/#{&1}")
            )
        end

        conn
        |> put_flash(:info, "Account created successfully!")
        |> UserAuth.login_user(user, user_params)

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_flash(:error, registration_error_message(changeset))
        |> redirect(to: ~p"/account/register")
    end
  end

  defp registration_error_message(changeset) do
    if Keyword.has_key?(changeset.errors, :email) do
      "That email is already taken or invalid. Please try again."
    else
      "Something went wrong. Please check your details and try again."
    end
  end
end
