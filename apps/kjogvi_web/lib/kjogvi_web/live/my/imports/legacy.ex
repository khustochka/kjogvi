defmodule KjogviWeb.Live.My.Imports.Legacy do
  @moduledoc """
  Legacy import live component.
  """

  use KjogviWeb, :live_component

  alias Phoenix.LiveView.AsyncResult

  @component_id "legacy-import"

  def on_mount(:attach, _params, _session, socket) do
    {:cont, attach_hook(socket, :legacy_import_progress, :handle_info, &handle_progress/2)}
  end

  defp handle_progress({:legacy_import_progress, data}, socket) do
    send_update(__MODULE__, id: @component_id, status: :progress, data: data)
    {:halt, socket}
  end

  defp handle_progress(_msg, socket), do: {:cont, socket}

  def mount(socket) do
    {
      :ok,
      socket
      |> assign(:async_result, %AsyncResult{})
    }
  end

  def update(%{user: user}, socket) do
    {
      :ok,
      socket
      |> assign(:user, user)
    }
  end

  def update(%{status: :ok, data: data}, socket) do
    {:ok,
     socket
     |> clear_flash()
     |> put_flash(:info, data.message)
     |> assign(:async_result, AsyncResult.ok(data.message))}
  end

  def update(%{status: :error, data: data}, %{assigns: assigns} = socket) do
    {:ok,
     socket
     |> clear_flash()
     |> put_flash(:error, "Legacy import failed: " <> data.message)
     |> assign(:async_result, AsyncResult.failed(assigns.async_result, data.message))}
  end

  def update(%{status: :progress, data: data}, socket) do
    {:ok,
     socket
     |> clear_flash()
     |> put_flash(:info, data.message)}
  end

  def handle_event("start_import", _params, socket) do
    {:noreply,
     socket
     |> start_import()}
  end

  defp start_import(%{assigns: %{user: user}} = socket) do
    import_id = Ecto.UUID.generate()
    Kjogvi.Legacy.Import.PubSub.subscribe(import_id)

    %{ref: ref} =
      Task.Supervisor.async_nolink(Kjogvi.TaskSupervisor, fn ->
        Kjogvi.Legacy.Import.run(user, import_id: import_id)
      end)

    send(self(), {:register_import, __MODULE__, @component_id, ref})

    socket
    |> clear_flash()
    |> assign(:async_result, AsyncResult.loading())
    |> put_flash(:info, "Legacy import in progress...")
  end

  def render(assigns) do
    ~H"""
    <div>
      <.main_flash id="legacy-import-flash" flash={@flash} />
      <CoreComponents.simple_form
        for={nil}
        phx-submit="start_import"
        phx-target={@myself}
        action={~p"/my/imports/legacy"}
      >
        <:actions>
          <%= if @async_result.loading do %>
            <CoreComponents.button disabled>Import</CoreComponents.button>
          <% else %>
            <CoreComponents.button>Import</CoreComponents.button>
          <% end %>
        </:actions>
      </CoreComponents.simple_form>
    </div>
    """
  end
end
