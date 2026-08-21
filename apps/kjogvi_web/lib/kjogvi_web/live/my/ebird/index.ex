defmodule KjogviWeb.Live.My.Ebird.Index do
  @moduledoc """
  The user's eBird import page: uploading an eBird export.

  The page carries no run history — the import task component reports the
  state of the latest run on its own. The full log of every run stays in the
  admin area.
  """

  use KjogviWeb, :live_view

  alias KjogviWeb.Live.My.Imports

  on_mount {Imports.EbirdCsv, :attach}

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "eBird Import")}
  end

  def render(assigns) do
    ~H"""
    <.h1>eBird Import</.h1>

    <div class="border border-slate-300 rounded-lg p-6 mb-8 lg:max-w-2xl">
      <.live_component
        module={Imports.EbirdCsv}
        user={@current_scope.current_user}
        id="ebird-csv-import"
      />
    </div>
    """
  end
end
