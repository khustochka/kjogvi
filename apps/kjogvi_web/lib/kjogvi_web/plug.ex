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

  def validate_lifelist_params(%{path_params: path_params} = conn, _opts) do
    conn
    |> assign(:year, validate_and_convert_year(path_params["year"]))
  end

  defp validate_and_convert_year(nil = _year) do
    nil
  end

  defp validate_and_convert_year(year) when is_binary(year) do
    if year =~ ~r/\A\d{4}\Z/ do
      String.to_integer(year)
    else
      raise KjogviWeb.Exception.BadParams
    end
  end

  defp validate_and_convert_year(_year) do
    raise KjogviWeb.Exception.BadParams
  end
end
