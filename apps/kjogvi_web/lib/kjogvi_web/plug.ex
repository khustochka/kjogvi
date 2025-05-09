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

  def verify_main_user(
        %{request_path: "/setup" <> _, assigns: %{current_scope: scope}} = conn,
        _opts
      ) do
    if scope.main_user do
      conn
      |> put_status(:not_found)
      |> put_view(Application.get_env(:kjogvi_web, KjogviWeb.Endpoint)[:render_errors][:formats])
      |> render(:"404")
      |> halt()
    else
      conn
    end
  end

  def verify_main_user(%{assigns: %{current_scope: scope}} = conn, _opts) do
    if scope.main_user do
      conn
    else
      conn
      |> redirect(to: ~p"/setup")
      |> halt()
    end
  end

  def set_private_view(%{assigns: %{current_scope: scope}} = conn, _opts) do
    conn
    |> assign(:current_scope, %{scope | private_view: true})
  end
end
