defmodule KjogviWeb.DiaryController do
  use KjogviWeb, :controller

  alias Kjogvi.Birding.Diary
  alias Kjogvi.Birding.Lifelist

  @spec show(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def show(%{assigns: assigns} = conn, _params) do
    diary_scope = Lifelist.Scope.from_scope(assigns.current_scope)

    diary_entries = Diary.recent_entries(diary_scope, limit: 366, cutoff_days: 366)

    conn
    |> assign(:diary_entries, diary_entries)
    |> render(:show)
  end
end
