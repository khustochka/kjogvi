defmodule KjogviWeb.My.ImportsController do
  use KjogviWeb, :controller

  def legacy(%{assigns: assigns} = conn, _params) do
    Kjogvi.Legacy.Import.run(assigns.current_scope.user)

    conn
    |> put_flash(:info, "Legacy import processed.")
    |> redirect(to: ~p"/my/imports")
  end
end
