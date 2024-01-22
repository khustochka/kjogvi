defmodule OrnithoWeb.LinkHelper do
  @moduledoc """
  Helpers to create links to OrnithoWeb pages.
  """

  def path(%{router: router}, path) do
    path_from_router(router, path)
  end

  def path(%{private: %{phoenix_router: router}}, path) do
    path_from_router(router, path)
  end

  defp path_from_router(router, path) do
    norm_path = String.trim_leading(path, "/")
    prefix = router.__ornitho_web_prefix__()
    "#{prefix}/#{norm_path}"
  end
end
