defmodule KjogviWeb.Live.My.Log.Index do
  @moduledoc false

  use KjogviWeb, :live_view

  alias Kjogvi.Birding.Log
  alias Kjogvi.Birding.Lifelist

  import KjogviWeb.LogComponents

  @impl true
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> assign(:page_title, "Birding log")
    }
  end

  @impl true
  def handle_params(_params, _url, %{assigns: assigns} = socket) do
    log_scope = Lifelist.Scope.from_scope(assigns.current_scope)

    log_entries = Log.recent_entries(log_scope, limit: 366, cutoff_days: 366)

    {
      :noreply,
      socket
      |> assign(:log_entries, log_entries)
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.log log_entries={@log_entries} current_scope={@current_scope} />
    """
  end
end
