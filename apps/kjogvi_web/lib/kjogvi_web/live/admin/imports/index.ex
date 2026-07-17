defmodule KjogviWeb.Live.Admin.Imports.Index do
  @moduledoc """
  Landing page for the admin import tools. Carries the shared section nav and
  links out to each import workbench (currently only location imports).
  """

  use KjogviWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Imports")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.h1>Imports</.h1>

      <ul class="flex flex-wrap gap-2">
        <li>
          <.action_button navigate={~p"/admin/imports/locations"} variant="secondary">
            Location Imports
          </.action_button>
        </li>
      </ul>
    </div>
    """
  end
end
