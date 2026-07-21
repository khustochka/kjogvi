defmodule KjogviWeb.Live.My.Imports.Ebird do
  @moduledoc """
  eBird preload live component.

  The preload runs as an exclusive Oban job (`Kjogvi.Jobs.EbirdPreload`, task
  key `{:ebird_preload, user_id}`): the component seeds from
  `Kjogvi.Jobs.status/2` and follows the progress/lifecycle events broadcast
  on the key's PubSub topic.
  """

  use KjogviWeb, :live_component

  alias Kjogvi.Jobs
  alias Kjogvi.Util.AsyncResult
  alias Kjogvi.Util.PubSubTopic

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

  # Lifecycle events (:start / :ok / :error) carry the AsyncResult ready to be
  # assigned as-is. The tagged event lets the component refresh its display
  # once the job succeeds.
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

  # On success the job has already persisted the checklists to the store and its
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
    {:noreply, start_ebird_preload(socket)}
  end

  # The job resolves its own credentials; checking them here too surfaces a
  # missing eBird configuration immediately instead of enqueuing a job doomed
  # to fail in the background. Inserting while a run is in flight returns the
  # existing job instead of enqueuing a second one, so re-reading the status
  # afterwards keeps the button state honest either way.
  defp start_ebird_preload(%{assigns: %{user: user}} = socket) do
    case Ebird.Web.ebird_credentials(user) do
      {:ok, _credentials} ->
        Store.ChecklistPreload.reset_preloads(user)
        {:ok, _job} = OpentelemetryOban.insert(Jobs.EbirdPreload.new(%{user_id: user.id}))

        socket
        |> clear_flash()
        |> assign(:async_result, Jobs.status(Jobs.EbirdPreload, %{user_id: user.id}))
        |> derive_flash()
        |> assign_preloads_data()

      {:error, error} ->
        socket
        |> clear_flash()
        |> assign(:async_result, AsyncResult.failed(AsyncResult.loading(%{}), error))
        |> derive_flash()
    end
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
      Jobs.status(Jobs.EbirdPreload, %{user_id: user.id})
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
