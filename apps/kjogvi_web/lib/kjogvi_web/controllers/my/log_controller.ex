defmodule KjogviWeb.LogController do
  use KjogviWeb, :controller

  alias Kjogvi.Birding.Log
  alias Kjogvi.Birding.Lifelist

  @spec show(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def show(%{assigns: assigns} = conn, _params) do
    log_scope = Lifelist.Scope.from_scope(assigns.current_scope)

    log_entries = Log.recent_entries(log_scope, limit: 366, cutoff_days: 366)

    conn
    |> assign(:page_title, "Birding log")
    |> assign(:log_entries, log_entries)
    |> render(:show)
  end
end
