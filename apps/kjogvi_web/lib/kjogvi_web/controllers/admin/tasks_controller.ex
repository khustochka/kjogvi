defmodule KjogviWeb.Admin.TasksController do
  use KjogviWeb, :controller

  @spec index(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def index(conn, _params) do
    render(conn, :index)
  end

  def legacy_import(conn, _params) do
    Kjogvi.Legacy.Import.run()

    conn
    |> put_flash(:info, "Legacy import processed.")
    |> redirect(to: ~p"/admin/tasks")
  end
end
