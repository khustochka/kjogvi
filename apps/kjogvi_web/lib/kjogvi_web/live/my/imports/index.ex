defmodule KjogviWeb.Live.My.Imports.Index do
  @moduledoc false

  use KjogviWeb, :live_view

  alias KjogviWeb.Live.My.Imports

  @imports [
    Imports.Legacy,
    Imports.Ebird
  ]

  @imports_data %{
    Imports.Legacy => {"Legacy Import", "legacy-import"},
    Imports.Ebird => {"eBird preload", "ebird-import"}
  }

  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> assign(:page_title, "Import Tasks")
      |> put_private(:running_imports, %{})
    }
  end

  def handle_info({:register_import, module, ref}, socket) when module in @imports do
    {:noreply,
     socket
     |> put_private(:running_imports, Map.put(running_imports(socket), ref, module))}
  end

  # TODO: refactor to make more universal
  def handle_info({:legacy_import_progress, data}, socket) do
    send_update(Imports.Legacy,
      id: "legacy-import",
      status: :progress,
      data: data
    )

    {:noreply, socket}
  end

  def handle_info({"ebird_preload_progress", data}, socket) do
    send_update(Imports.Ebird,
      id: "ebird-import",
      status: :progress,
      data: data
    )

    {:noreply, socket}
  end

  # Successful import tasks should return {:ok, data}
  def handle_info({ref, {:ok, data}}, socket) do
    pass_back(:ok, ref, data, socket)
  end

  def handle_info({ref, {:error, data}}, socket) do
    pass_back(:error, ref, data, socket)
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, socket) do
    pass_back(:error, ref, %{message: "Server error."}, socket)
  end

  def render(assigns) do
    ~H"""
    <.h1>Import Tasks</.h1>

    <div class="lg:grid lg:grid-cols-2 lg:gap-x-14 lg:gap-y-8">
      <%= for module <- imports(), {header, id} = imports_data(module) do %>
        <div class="border border-slate-300 rounded-lg p-6 mb-6">
          <.h2>{header}</.h2>
          <.live_component module={module} user={@current_scope.user} id={id} />
        </div>
      <% end %>
    </div>
    """
  end

  defp imports do
    @imports
  end

  defp imports_data(module) do
    @imports_data[module]
  end

  defp running_imports(socket) do
    socket.private[:running_imports]
  end

  def find_running_import(socket, ref) do
    module = running_imports(socket)[ref]
    id = imports_data(module) |> elem(1)

    {module, id}
  end

  defp delete_running_import(socket, ref) do
    socket |> put_private(:running_imports, running_imports(socket) |> Map.delete(ref))
  end

  defp pass_back(status, ref, data, socket) do
    Process.demonitor(ref, [:flush])
    {module, id} = find_running_import(socket, ref)

    send_update(module,
      id: id,
      status: status,
      data: data
    )

    {:noreply, socket |> delete_running_import(ref)}
  end
end
