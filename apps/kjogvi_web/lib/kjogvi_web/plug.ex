defmodule KjogviWeb.Plug do
  @moduledoc """
  Your project's custom function plugs.
  """

  use KjogviWeb, :controller

  @doc """
  If a non-root URL ends with a slash '/', do a permanent redirect to a URL that
  removes it.

  Source: https://www.moendigital.com/blog/phoenix-url-remove-trailing-slash/?utm_medium=email&utm_source=elixir-radar
  """
  def remove_trailing_slash(conn, _opts) do
    if conn.request_path != "/" && String.last(conn.request_path) == "/" do
      # trailing slash detected: return a permanent redirect to a URL without
      # the trailing slash, and halt the current request
      conn
      |> put_status(301)
      |> redirect(to: String.slice(conn.request_path, 0..-2//1))
      |> halt()
    else
      # no trailing slash detected. the request will continue down the plug
      # pipeline
      conn
    end
  end

  @doc """
  Finds the main user in single-user mode.
  """
  def fetch_main_user(conn, _opts) do
    if String.starts_with?(conn.request_path, "/setup") do
      conn
    else
      case Kjogvi.Settings.main_user() do
        nil ->
          conn
          |> put_status(301)
          |> redirect(to: ~p"/setup")
          |> halt()

        user ->
          assign(conn, :main_user, user)
      end
    end
  end
end
