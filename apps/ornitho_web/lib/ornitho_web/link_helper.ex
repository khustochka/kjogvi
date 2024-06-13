defmodule OrnithoWeb.LinkHelper do
  @moduledoc """
  Helpers to create links to OrnithoWeb pages.
  """

  def root_path(conn_or_socket, params \\ []) do
    routed_path(conn_or_socket, "/", params)
  end

  def book_path(conn_or_socket, book, params \\ []) do
    {page, params} = pop_in(params, [:page])

    path =
      case page do
        n when n in [nil, "", 0, "0", 1, "1"] -> "#{book.slug}/#{book.version}"
        n -> "#{book.slug}/#{book.version}/page/#{n}"
      end

    routed_path(conn_or_socket, path, params)
  end

  def import_path(conn_or_socket, params \\ []) do
    routed_path(conn_or_socket, "import", params)
  end

  defp routed_path(conn_or_socket, path, params) do
    router = _router(conn_or_socket)

    Phoenix.VerifiedRoutes.unverified_path(
      conn_or_socket,
      router,
      path_from_router(router, path),
      params
    )
  end

  def path(%{router: router}, path) do
    path_from_router(router, path)
  end

  def path(%{private: %{phoenix_router: router}}, path) do
    path_from_router(router, path)
  end

  defp _router(%{router: router}) do
    router
  end

  defp _router(%{private: %{phoenix_router: router}}) do
    router
  end

  defp path_from_router(router, path) do
    norm_path = String.trim_leading(path, "/")
    prefix = router.__ornitho_web_prefix__()
    "#{prefix}/#{norm_path}"
  end
end
