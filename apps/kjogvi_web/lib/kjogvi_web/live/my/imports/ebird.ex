defmodule KjogviWeb.Live.My.Imports.Ebird do
  @moduledoc """
  eBird preload live component.
  """

  use KjogviWeb, :live_component

  alias Kjogvi.Util.AsyncResult
  alias Kjogvi.Util.PubSubTopic
  alias Kjogvi.Server.ExclusiveTaskProcessor

  alias Kjogvi.Ebird
  alias Kjogvi.Store

  @component_id "ebird-import"

  def on_mount(:attach, _params, _session, socket) do
    {:cont, attach_hook(socket, :ebird_import_progress, :handle_info, &handle_progress/2)}
  end

  defp handle_progress({:progress, {:ebird_preload, _user_id}, status}, socket) do
    send_update(__MODULE__,
      id: @component_id,
      async_result: AsyncResult.loading(status)
    )

    {:halt, socket}
  end

  # Lifecycle events (:start / :ok / :error) carry the AsyncResult exactly as the
  # processor stores it, so it can be assigned as-is. The tagged event lets the
  # component refresh its display once the task succeeds.
  defp handle_progress({:lifecycle, event, {:ebird_preload, _user_id}, async_result}, socket) do
    send_update(__MODULE__,
      id: @component_id,
      lifecycle: event,
      async_result: async_result
    )

    {:halt, socket}
  end

  defp handle_progress(_msg, socket), do: {:cont, socket}

  def update(%{user: user}, socket) do
    {
      :ok,
      socket
      |> assign(:user, user)
      |> assign_preloads_data()
      |> subscribe_once()
    }
  end

  # On success the task has already persisted the checklists to the store and its
  # result carries the completion message. Refresh the displayed preload data
  # from the store and surface that message in the flash.
  def update(%{lifecycle: :ok, async_result: async_result}, socket) do
    {:ok,
     socket
     |> assign(:async_result, async_result)
     |> assign_preloads_data()
     |> derive_flash()}
  end

  def update(%{async_result: async_result}, socket) do
    {:ok,
     socket
     |> clear_flash()
     |> assign(:async_result, async_result)
     |> derive_flash()}
  end

  def handle_event("start_preload", _params, socket) do
    {:noreply,
     socket
     |> assign(:ebird_checklists, [])
     |> start_ebird_preload()}
  end

  defp start_ebird_preload(%{assigns: %{user: user}} = socket) do
    # Resolve eBird credentials here (in the DB-connected LiveView) so the
    # background task receives ready credentials and, when unconfigured, we
    # surface the error immediately instead of spawning a task.
    case Ebird.Web.ebird_credentials(user) do
      {:ok, credentials} ->
        Store.ChecklistPreload.reset_preloads(user)
        start_ebird_preload_task(user, credentials)

        socket
        |> clear_flash()
        |> assign(:async_result, AsyncResult.loading(%{message: "eBird preload in progress..."}))
        |> derive_flash()
        |> assign_preloads_data()

      {:error, error} ->
        socket
        |> clear_flash()
        |> assign(:async_result, AsyncResult.failed(AsyncResult.loading(%{}), error))
        |> derive_flash()
    end
  end

  defp start_ebird_preload_task(user, credentials) do
    Kjogvi.Server.ExclusiveTaskProcessor.start_task(
      {:ebird_preload, user.id},
      fn key ->
        # Persist the checklists inside the task itself, so they are stored even
        # if this LiveView is closed before the task finishes (the :ok lifecycle
        # callback below only runs while a subscriber is alive). The store is the
        # source of truth for the list, so the result only needs to carry the
        # completion message that subscribers (this component, the admin
        # dashboard) display.
        with {:ok, checklists} <-
               Ebird.Web.preload_new_checklists_for_user(user, credentials, broadcast_key: key) do
          Store.ChecklistPreload.store_checklists(user, checklists)
          {:ok, %{message: "eBird preload done: #{length(checklists)} new checklists."}}
        end
      end,
      message: "eBird preload in progress...",
      timeout: 2 * 60 * 1000
    )
  end

  def render(assigns) do
    ~H"""
    <div>
      <.main_flash id="ebird-preload-flash" flash={@flash} />
      <.form
        id="ebird-preload-form"
        for={nil}
        phx-submit="start_preload"
        phx-target={@myself}
        class="mb-10"
      >
        <div class="mt-8 space-y-8 bg-white">
          <div class="mt-2 flex items-center justify-between gap-6">
            <%= if @async_result.loading do %>
              <.button disabled>Preload</.button>
            <% else %>
              <.button>Preload</.button>
            <% end %>
          </div>
        </div>
      </.form>

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

  # The PubSub subscription and initial status snapshot belong to the component's
  # lifetime, not to each parent re-render. `assign_new` seeds `async_result` the
  # first time the component is updated and is a no-op thereafter, so subsequent
  # renders keep the live `async_result` maintained by the progress/lifecycle
  # pushes instead of re-subscribing and clobbering it with a staler snapshot.
  defp subscribe_once(%{assigns: %{user: user}} = socket) do
    key = {:ebird_preload, user.id}

    socket
    |> assign_new(:async_result, fn ->
      Phoenix.PubSub.subscribe(Kjogvi.PubSub, PubSubTopic.for_key(key))
      ExclusiveTaskProcessor.get_status(key)
    end)
    |> derive_flash()
  end

  defp derive_flash(%{assigns: %{async_result: async_result}} = socket) do
    cond do
      async_result.failed ->
        put_flash(
          socket,
          :error,
          "eBird preload failed: " <> result_message(async_result.failed, "Server error.")
        )

      async_result.loading ->
        put_flash(socket, :info, result_message(async_result.loading, "In progress..."))

      async_result.ok? ->
        put_flash(socket, :info, result_message(async_result.result, "Success."))

      :otherwise ->
        clear_flash(socket)
    end
  end

  defp result_message(%{message: message}, _default), do: message
  defp result_message(:timeout, _default), do: "Timeout"
  defp result_message(_other, default), do: default
end
