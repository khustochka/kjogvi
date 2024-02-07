defmodule KjogviWeb.Live.Admin.Tasks.Index do
  use KjogviWeb, :live_view

  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> assign(:page_title, "Admin Tasks")
    }
  end

  def handle_event("legacy_import", _params, socket) do
    Kjogvi.Legacy.Import.run()

    {:noreply,
     socket
    |> put_flash(:info, "Legacy import processed.")}
  end

  def render(assigns) do
    ~H"""
    <.header>Admin Tasks</.header>
    <h2>Legacy Import</h2>
    <.simple_form for={nil} phx-submit="legacy_import" action={~p"/admin/tasks/legacy_import"}>
      <:actions>
        <.button phx-disable-with="processing...">Import</.button>
      </:actions>
    </.simple_form>
    """
  end
end
