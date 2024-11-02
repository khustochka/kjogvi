defmodule KjogviWeb.Live.Admin.Tasks.Index do
  @moduledoc false

  use KjogviWeb, :live_view

  alias Phoenix.LiveView.AsyncResult

  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> assign(:page_title, "Admin Tasks")
      |> assign(:async_result, %AsyncResult{})
    }
  end

  def handle_event("legacy_import", _params, socket) do
    {:noreply,
     socket
     |> start_legacy_import()
     |> clear_flash()}
  end

  defp start_legacy_import(%{assigns: %{current_user: current_user}} = socket) do
    # live_view_pid = self()
    socket
    |> assign(:async_result, AsyncResult.loading())
    |> start_async(:legacy_import, fn ->
      Kjogvi.Legacy.Import.run(current_user)
      # Enum.each(1..5, fn n ->
      #   Process.sleep(1_000)
      #   IO.puts("SENDING ASYNC TASK MESSAGE #{n}")
      #   send(live_view_pid, {:task_message, "Async work chunk #{n}"})
      # end)
      :ok
    end)
  end

  def handle_async(:legacy_import, {:ok, :ok = _success_result}, socket) do
    socket =
      socket
      |> put_flash(:info, "Legacy import done.")
      |> assign(:async_result, AsyncResult.ok(%AsyncResult{}, :ok))

    {:noreply, socket}
  end

  def handle_async(:legacy_import, {:exit, reason}, socket) do
    socket =
      socket
      |> put_flash(:error, "Legacy import failed: #{inspect(reason)}")
      |> assign(:async_result, %AsyncResult{})

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <.header_single>Admin Tasks</.header_single>
    <h2>Legacy Import</h2>
    <CoreComponents.simple_form
      for={nil}
      phx-submit="legacy_import"
      action={~p"/admin/tasks/legacy_import"}
    >
      <:actions>
        <%= if @async_result.loading do %>
          <CoreComponents.button disabled>processing...</CoreComponents.button>
        <% else %>
          <CoreComponents.button>Import</CoreComponents.button>
        <% end %>
      </:actions>
    </CoreComponents.simple_form>
    """
  end
end
