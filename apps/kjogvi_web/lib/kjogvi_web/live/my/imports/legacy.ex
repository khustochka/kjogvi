defmodule KjogviWeb.Live.My.Imports.Legacy do
  @moduledoc """
  Legacy import live component.

  The import runs as an exclusive Oban job (`Kjogvi.Jobs.LegacyImport`, task
  key `{:legacy_import, user_id}`): the component seeds from
  `Kjogvi.Jobs.status/2` and follows the progress/lifecycle events broadcast
  on the key's PubSub topic.
  """

  alias Kjogvi.Accounts
  use KjogviWeb, :live_component

  alias Kjogvi.Jobs
  alias Kjogvi.Util.AsyncResult
  alias Kjogvi.Util.PubSubTopic

  @component_id "legacy-import"

  def on_mount(:attach, _params, _session, %{assigns: assigns} = socket) do
    {:cont,
     if Accounts.admin?(assigns.current_scope.current_user) do
       attach_hook(socket, :legacy_import_progress, :handle_info, &handle_progress/2)
     else
       socket
     end}
  end

  defp handle_progress({:progress, {:legacy_import, _user_id}, status}, socket) do
    send_update(__MODULE__,
      id: @component_id,
      async_result: AsyncResult.loading(status)
    )

    {:halt, socket}
  end

  # Lifecycle events (:start / :ok / :error) carry the AsyncResult ready to
  # be assigned as-is.
  defp handle_progress({:lifecycle, _event, {:legacy_import, _user_id}, async_result}, socket) do
    send_update(__MODULE__,
      id: @component_id,
      async_result: async_result
    )

    {:halt, socket}
  end

  defp handle_progress(_msg, socket), do: {:cont, socket}

  def update(%{user: user}, socket) do
    {:ok, socket |> assign(:user, user) |> subscribe_once()}
  end

  def update(%{async_result: async_result}, socket) do
    {:ok,
     socket
     |> clear_flash()
     |> assign(:async_result, async_result)
     |> derive_flash()}
  end

  # The PubSub subscription and initial status snapshot belong to the component's
  # lifetime, not to each parent re-render. `assign_new` seeds `async_result` the
  # first time the component is updated and is a no-op thereafter, so subsequent
  # renders keep the live `async_result` maintained by the progress/lifecycle
  # pushes instead of re-subscribing and clobbering it with a staler snapshot.
  defp subscribe_once(%{assigns: %{user: user}} = socket) do
    key = {:legacy_import, user.id}

    socket
    |> assign_new(:async_result, fn ->
      Phoenix.PubSub.subscribe(Kjogvi.PubSub, PubSubTopic.for_key(key))
      Jobs.status(Jobs.LegacyImport, %{user_id: user.id})
    end)
    |> derive_flash()
  end

  def handle_event("start_import", _params, socket) do
    {:noreply,
     socket
     |> start_import()}
  end

  # Inserting while a run is in flight returns the existing job instead of
  # enqueuing a second one, so re-reading the status afterwards keeps the
  # button state honest either way.
  defp start_import(%{assigns: %{user: user}} = socket) do
    {:ok, _job} = Oban.insert(Jobs.LegacyImport.new(%{user_id: user.id}))

    socket
    |> clear_flash()
    |> assign(:async_result, Jobs.status(Jobs.LegacyImport, %{user_id: user.id}))
    |> derive_flash()
  end

  def render(assigns) do
    ~H"""
    <div>
      <.main_flash id="legacy-import-flash" flash={@flash} />
      <.form
        id="legacy-import-form"
        for={nil}
        phx-submit="start_import"
        phx-target={@myself}
      >
        <div class="mt-8 space-y-8 bg-white">
          <div class="mt-2 flex items-center justify-between gap-6">
            <%= if @async_result.loading do %>
              <.button disabled>Import</.button>
            <% else %>
              <.button>Import</.button>
            <% end %>
          </div>
        </div>
      </.form>
    </div>
    """
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

  defp result_message(%{message: message}, _default) when not is_nil(message), do: message
  defp result_message(:timeout, _default), do: "Timeout"
  defp result_message(_other, default), do: default
end
