defmodule KjogviWeb.Admin.TasksHTML do
  use KjogviWeb, :html

  def index(assigns) do
    ~H"""
    <.header>Admin Tasks</.header>
    <h2>Legacy Import</h2>
    <.simple_form for={nil} phx-submit="import" action={~p"/admin/tasks/legacy_import"}>
      <:actions>
        <.button phx-disable-with="processing...">Import</.button>
      </:actions>
    </.simple_form>
    """
  end
end
