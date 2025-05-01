defmodule KjogviWeb.Live.My.Imports.Ebird do
  @moduledoc """
  eBird preload live component.
  """

  use KjogviWeb, :live_component

  alias Phoenix.LiveView.AsyncResult
  alias Kjogvi.Ebird
  alias Kjogvi.Store

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
      |> assign_preloads_data()
    }
  end

  def update(%{status: :ok, data: ebird_checklists}, socket) do
    Store.ChecklistPreload.store_checklists(socket.assigns.user, ebird_checklists)

    {:ok,
     socket
     |> assign_preloads_data()
     |> clear_flash()
     |> put_flash(:info, "eBird preload done: #{length(ebird_checklists)} new checklists.")
     |> assign(:async_result, AsyncResult.ok(%AsyncResult{}, :ok))}
  end

  def update(%{status: :error, data: data}, socket) do
    data =
      case data do
        message when is_binary(message) -> %{message: message}
        _ -> data
      end

    {:ok,
     socket
     |> clear_flash()
     |> put_flash(:error, "eBird preload failed: " <> data.message)
     |> assign(:async_result, AsyncResult.failed(%AsyncResult{}, data.message))}
  end

  def update(%{status: :progress, data: data}, socket) do
    {:ok,
     socket
     |> clear_flash()
     |> put_flash(:info, data.message)}
  end

  def handle_event("start_preload", _params, socket) do
    {:noreply,
     socket
     |> assign(:ebird_checklists, [])
     |> start_ebird_preload()}
  end

  defp start_ebird_preload(%{assigns: %{user: user}} = socket) do
    import_id = Ecto.UUID.generate()
    Ebird.Web.subscribe_progress(:preload, import_id)

    Store.ChecklistPreload.reset_preloads(user)

    %{ref: ref} =
      Task.Supervisor.async_nolink(Kjogvi.TaskSupervisor, fn ->
        Ebird.Web.preload_new_checklists_for_user(user, import_id: import_id)
      end)

    send(self(), {:register_import, __MODULE__, ref})

    socket
    |> clear_flash()
    |> put_flash(:info, "eBird import in progress...")
    |> assign(:async_result, AsyncResult.loading())
    |> assign_preloads_data()
  end

  def handle_async(:ebird_preload, {:exit, _reason}, socket) do
    socket =
      socket
      |> clear_flash()
      |> put_flash(:error, "eBird preload failed: Server error")
      |> assign(:async_result, %AsyncResult{})

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.main_flash id="ebird-preload-flash" flash={@flash} />
      <CoreComponents.simple_form
        for={nil}
        phx-submit="start_preload"
        phx-target={@myself}
        class="mb-10"
      >
        <:actions>
          <%= if @async_result.loading do %>
            <CoreComponents.button disabled>Preload</CoreComponents.button>
          <% else %>
            <CoreComponents.button>Preload</CoreComponents.button>
          <% end %>
        </:actions>
      </CoreComponents.simple_form>

      <p>
        <b>Last preloaded:</b>
        <span>
          <%= if @preloads.last_preload_time do %>
            <time time={@preloads.last_preload_time}>
              {Calendar.strftime(@preloads.last_preload_time, "%-d %b %Y %m:%S")}
            </time>
          <% else %>
            <i>no data</i>
          <% end %>
        </span>
      </p>

      <ul :for={checklist <- @preloads.checklists} class="my-4">
        <li>
          {checklist.date}, {checklist.time}, {checklist.location}
        </li>
      </ul>
    </div>
    """
  end

  defp assign_preloads_data(socket) do
    socket
    |> assign(:preloads, Store.ChecklistPreload.get_preloads(socket.assigns.user))
  end
end
