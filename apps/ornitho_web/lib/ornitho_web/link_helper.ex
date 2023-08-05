defmodule OrnithoWeb.LinkHelper do
  def path(%{router: router}, path) do
    path_from_router(router, path)
  end

  def path(%{private: %{phoenix_router: router}}, path) do
    path_from_router(router, path)
  end

  defp path_from_router(router, path) do
    prefix = router.__ornitho_web_prefix__()
    "#{prefix}/#{path}"
  end
end
