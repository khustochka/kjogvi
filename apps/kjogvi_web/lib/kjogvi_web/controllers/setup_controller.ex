defmodule KjogviWeb.SetupController do
  use KjogviWeb, :controller

  require Logger

  alias Kjogvi.Users
  alias Kjogvi.Users.User

  @rand_size 32

  plug :put_layout, false when action in [:enter, :form]
  plug :put_setup_code when action == :enter
  plug :verify_setup_code when action in [:form, :create]

  def enter(conn, _params) do
    conn
    |> render(:enter)
  end

  def form(conn, _params) do
    form =
      Users.change_user_registration(%User{})
      |> Phoenix.Component.to_form(as: "user")

    conn
    |> assign(:check_errors, false)
    |> assign(:form, form)
    |> assign(:setup_code, get_session(conn, :setup_code))
    |> render(:form)
  end

  def create(conn, %{"user" => user_params}) do
    case Users.register_admin(user_params) do
      {:ok, _} ->
        conn
        |> delete_session(:setup_code)
        |> put_flash(:info, "Admin user set up.")
        |> redirect(to: ~p"/users/log_in")

      {:error, %Ecto.Changeset{} = changeset} ->
        form = Phoenix.Component.to_form(changeset, as: "user")

        conn
        |> assign(:check_errors, !changeset.valid?)
        |> assign(:form, form)
        |> render(:new)
    end
  end

  defp put_setup_code(conn, _opts) do
    if get_session(conn, :setup_code) do
      conn
    else
      conn
      |> put_session(:setup_code, get_setup_code())
    end
  end

  defp get_setup_code() do
    case Application.get_env(:kjogvi, :setup_code) do
      nil -> generate_setup_code()
      code -> code
    end
  end

  defp generate_setup_code() do
    :crypto.strong_rand_bytes(@rand_size)
    |> Base.encode16(case: :lower)
    |> tap(fn code ->
      Logger.log(:info, "[setup] Setup code: #{code}")
    end)
  end

  defp verify_setup_code(%{params: params} = conn, _opts) do
    code = params["setup_code"]
    expected_code = get_session(conn, :setup_code)

    if !is_nil(expected_code) && code == expected_code do
      conn
    else
      conn
      |> delete_session(:setup_code)
      |> put_flash(:error, "Incorrect code.")
      |> redirect(to: ~p"/setup")
      |> halt()
    end
  end
end
