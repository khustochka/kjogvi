defmodule KjogviWeb.Plug do
  @moduledoc """
  Your project's custom function plugs.
  """

  use KjogviWeb, :controller

  @doc """
  Redirects to `/setup` while no admin user exists, so the app forces initial
  setup before anything else can be reached. The setup routes themselves are
  exempt to avoid a redirect loop. Once an admin exists this is a no-op (see
  `Kjogvi.Accounts.admin_exists?/0`).
  """
  def require_setup(%{path_info: ["setup" | _]} = conn, _opts), do: conn

  def require_setup(conn, _opts) do
    if Kjogvi.Accounts.admin_exists?() do
      conn
    else
      conn
      |> redirect(to: ~p"/setup")
      |> halt()
    end
  end

  @doc """
  Makes the setup routes available only while no admin user exists. Once an
  admin exists they respond with 404.
  """
  def require_no_admin(conn, _opts) do
    if Kjogvi.Accounts.admin_exists?() do
      conn
      |> put_status(:not_found)
      |> put_view(KjogviWeb.ErrorHTML)
      |> render(:"404")
      |> halt()
    else
      conn
    end
  end

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
  Refines the scope into the `:private` area: the logged-in user views their
  own data, including private records. Mirrors `mount_area_private/4`.
  """
  def put_area_private(%{assigns: %{current_scope: scope}} = conn, _opts) do
    conn
    |> assign(:current_scope, %{scope | area: :private, subject_user: scope.current_user})
    |> apply_layout()
  end

  @doc """
  Refines the scope into the `:admin` area. Like `:private` it shows the
  admin's own data under the private chrome, but the distinct area value lets
  admin-only code branch on it. Mirrors `mount_area_admin/4`.
  """
  def put_area_admin(%{assigns: %{current_scope: scope}} = conn, _opts) do
    conn
    |> assign(:current_scope, %{scope | area: :admin, subject_user: scope.current_user})
    |> apply_layout()
  end

  # Sets the app layout from the (already-established) area. Layout is derived
  # from the scope, never chosen by the controller itself.
  defp apply_layout(%{assigns: %{current_scope: scope}} = conn) do
    put_layout(conn, html: {KjogviWeb.Layouts, KjogviWeb.Layouts.for_scope(scope)})
  end

  @doc """
  Responds with a 404 status for filtered lifelist requests that match no
  observations, while still letting the page render normally — crawlers stop
  indexing arbitrary filter combinations, users see the regular empty page.
  The unfiltered lifelist stays 200 even when empty. Invalid filter params
  pass through and 404 in the LiveView itself.
  """
  def put_lifelist_status(%{path_info: path_info} = conn, _opts) do
    if lifelist_request?(path_info) do
      put_status_for_lifelist(conn)
    else
      conn
    end
  end

  defp lifelist_request?(["community", "lifelist" | _]), do: true
  defp lifelist_request?(["users", _username, "lifelist" | _]), do: true
  defp lifelist_request?(_), do: false

  defp put_status_for_lifelist(%{assigns: %{current_scope: scope}} = conn) do
    case KjogviWeb.Live.Lifelist.Params.to_filter(scope, conn.params) do
      {:ok, filter} ->
        if narrowing_filter?(filter) and not Kjogvi.Birding.Lifelist.has_entries?(scope, filter) do
          put_status(conn, :not_found)
        else
          conn
        end

      {:error, _} ->
        conn
    end
  end

  # Only narrowed requests are 404 candidates; the base lifelist renders 200
  # even when empty. `exclude_heard_only` does not narrow — heard-only species
  # still render as extras.
  defp narrowing_filter?(%{year: nil, month: nil, location: nil, motorless: false}), do: false
  defp narrowing_filter?(_filter), do: true

  @doc """
  Refines the scope into the `:user` area: resolves `:username` to a user and
  assigns it as `subject_user`. Renders 404 if no user matches the nickname.
  """
  def put_area_user(
        %{assigns: %{current_scope: scope}, params: %{"username" => username}} = conn,
        _opts
      ) do
    case Kjogvi.Accounts.get_user_by_nickname(username) do
      nil ->
        conn
        |> put_status(:not_found)
        |> put_view(KjogviWeb.ErrorHTML)
        |> render(:"404")
        |> halt()

      subject_user ->
        conn
        |> assign(:current_scope, %{scope | area: :user, subject_user: subject_user})
        |> apply_layout()
    end
  end
end
