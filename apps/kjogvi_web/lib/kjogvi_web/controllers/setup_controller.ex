defmodule KjogviWeb.SetupController do
  use KjogviWeb, :controller

  require Logger

  @rand_size 32

  plug :put_layout, false
  plug :put_setup_code when action == :enter

  def enter(conn, _params) do
    conn
    |> render(:enter)
  end

  def new(conn, %{"code" => code}) do
    if code == get_session(conn, :setup_code) do
      conn
      |> send_resp(200, "Success")
      |> halt()
    else
      conn
      |> delete_session(:setup_code)
      |> put_flash(:error, "Incorrect code")
      |> redirect(to: ~p"/setup")
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

  def get_setup_code() do
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
end
