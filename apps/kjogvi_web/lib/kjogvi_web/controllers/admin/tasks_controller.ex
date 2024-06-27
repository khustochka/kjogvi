defmodule KjogviWeb.Admin.TasksController do
  use KjogviWeb, :controller

  def legacy_import(%{assigns: assigns} = conn, _params) do
    Kjogvi.Legacy.Import.run(assigns.current_user)

    conn
    |> put_flash(:info, "Legacy import processed.")
    |> redirect(to: ~p"/admin/tasks")
  end
end
