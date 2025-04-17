defmodule KjogviWeb.My.ImagesController do
  @moduledoc false

  use KjogviWeb, :controller

  alias Kjogvi.Media

  require Logger

  def create(conn, params) do
    Media.create_image(conn.assigns.current_scope, params["image"])
    |> case do
      {:ok, image} ->
        conn
        |> redirect(to: ~p"/my/images/#{image}")

      {:error, changeset} ->
        Logger.error(changeset |> inspect())

        conn
        |> put_flash(:error, "Error")
        |> redirect(to: ~p"/my/images/new")
    end
  end
end
