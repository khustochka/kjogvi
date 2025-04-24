defmodule KjogviWeb.Live.My.Imports.Index do
  @moduledoc false

  use KjogviWeb, :live_view

  alias KjogviWeb.Live.My.Imports

  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> assign(:page_title, "Import Tasks")
    }
  end

  def handle_info({:legacy_import_progress, %{message: message}}, socket) do
    send_update(Imports.Legacy,
      id: "legacy-import",
      source: :legacy_import_progress,
      message: message
    )

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <.h1>Import Tasks</.h1>

    <div class="lg:grid lg:grid-cols-2 lg:gap-x-14 lg:gap-y-8">
      <%= for {header, module, id} <- [{"Legacy Import", Imports.Legacy, "legacy-import"}, {"eBird preload", Imports.Ebird, "ebird-import"}] do %>
        <div class="border border-slate-300 rounded-lg p-6 mb-6">
          <.h2>{header}</.h2>
          <.live_component module={module} user={@current_scope.user} id={id} />
        </div>
      <% end %>
    </div>
    """
  end
end
