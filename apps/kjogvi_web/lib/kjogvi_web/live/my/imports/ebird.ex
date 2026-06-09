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
  # component persist the freshly preloaded checklists once the task succeeds.
  defp handle_progress({:lifecycle, event, {:ebird_preload, _user_id}, async_result}, socket) do
    send_update(__MODULE__,
      id: @component_id,
      lifecycle: event,
      async_result: async_result
    )

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
    # FIXME: do not run on re-render
    Phoenix.PubSub.subscribe(Kjogvi.PubSub, PubSubTopic.for_key({:ebird_preload, user.id}))
    current_status = ExclusiveTaskProcessor.get_status({:ebird_preload, user.id})

    {
      :ok,
      socket
      |> assign(:user, user)
      |> assign_preloads_data()
      |> assign(:async_result, current_status)
      |> derive_flash()
    }
  end

  # On success the task's result is the list of newly preloaded checklists.
  # Persist them and refresh the displayed preload data, then surface a count in
  # the flash via an AsyncResult carrying a message.
  def update(%{lifecycle: :ok, async_result: async_result}, %{assigns: %{user: user}} = socket) do
    checklists = async_result.result
    Store.ChecklistPreload.store_checklists(user, checklists)

    message = "eBird preload done: #{length(checklists)} new checklists."

    {:ok,
     socket
     |> assign(:async_result, AsyncResult.ok(async_result, %{message: message}))
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
    Store.ChecklistPreload.reset_preloads(user)

    Kjogvi.Server.ExclusiveTaskProcessor.start_task(
      {:ebird_preload, user.id},
      fn key ->
        Ebird.Web.preload_new_checklists_for_user(user, broadcast_key: key)
      end,
      message: "eBird preload in progress..."
    )

    socket
    |> clear_flash()
    |> assign(:async_result, AsyncResult.loading(%{message: "eBird preload in progress..."}))
    |> derive_flash()
    |> assign_preloads_data()
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

  defp derive_flash(%{assigns: %{async_result: async_result}} = socket) do
    cond do
      async_result.failed ->
        put_flash(
          socket,
          :error,
          "Legacy import failed: " <> result_message(async_result.failed, "Server error.")
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
  defp result_message(_other, default), do: default
end
