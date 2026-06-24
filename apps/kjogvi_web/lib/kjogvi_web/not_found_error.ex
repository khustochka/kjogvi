defmodule KjogviWeb.NotFoundError do
  @moduledoc """
  Raised to render a 404 response. `Plug.Exception` maps `plug_status` to the
  HTTP status, so raising this anywhere in the request lifecycle yields a 404.
  """

  defexception message: "Not found", plug_status: 404
end
