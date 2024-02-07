defmodule KjogviWeb.Admin.TasksController do
  use KjogviWeb, :controller

  def legacy_import(conn, _params) do
    Kjogvi.Legacy.Import.run()

    conn
    |> put_flash(:info, "Legacy import processed.")
    |> redirect(to: ~p"/admin/tasks")
  end
end
