defmodule KjogviWeb.UserController do
  use KjogviWeb, :controller

  alias Kjogvi.Users

  def update(conn, %{"user" => user_params}) do
    case Users.update_user_settings(conn.assigns.current_scope.user, user_params) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "User account updated.")

      {:error, _} ->
        conn
        |> put_flash(:error, "Error updating user account.")
    end
    |> redirect(to: ~p"/my/account/settings")
  end
end
