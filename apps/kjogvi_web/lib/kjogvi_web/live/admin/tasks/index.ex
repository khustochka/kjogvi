defmodule KjogviWeb.Live.Admin.Tasks.Index do
  @moduledoc false

  use KjogviWeb, :live_view

  alias Phoenix.LiveView.AsyncResult
  alias Kjogvi.Ebird

  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> assign(:page_title, "Admin Tasks")
      |> assign(:legacy_import_async_result, %AsyncResult{})
      |> assign(:ebird_preload_async_result, %AsyncResult{})
      |> assign(:ebird_checklists, [])
    }
  end

  def handle_event("legacy_import", _params, socket) do
    {:noreply,
     socket
     |> start_legacy_import()
     |> clear_flash()}
  end

  def handle_event("ebird_preload", _params, socket) do
    {:noreply,
     socket
     |> start_ebird_preload()
     |> clear_flash()
     |> assign(:ebird_checklists, [])}
  end

  defp start_legacy_import(%{assigns: %{current_scope: %{user: user}}} = socket) do
    # live_view_pid = self()
    socket
    |> assign(:legacy_import_async_result, AsyncResult.loading())
    |> start_async(:legacy_import, fn ->
      Kjogvi.Legacy.Import.run(user)
      # Enum.each(1..5, fn n ->
      #   Process.sleep(1_000)
      #   IO.puts("SENDING ASYNC TASK MESSAGE #{n}")
      #   send(live_view_pid, {:task_message, "Async work chunk #{n}"})
      # end)
      :ok
    end)
  end

  defp start_ebird_preload(%{assigns: %{current_scope: %{user: user}}} = socket) do
    # live_view_pid = self()
    socket
    |> assign(:ebird_preload_async_result, AsyncResult.loading())
    |> start_async(:ebird_preload, fn ->
      Ebird.Web.preload_new_checklists_for_user(user)
      # Enum.each(1..5, fn n ->
      #   Process.sleep(1_000)
      #   IO.puts("SENDING ASYNC TASK MESSAGE #{n}")
      #   send(live_view_pid, {:task_message, "Async work chunk #{n}"})
      # end)
    end)
  end

  def handle_async(:legacy_import, {:ok, :ok = _success_result}, socket) do
    socket =
      socket
      |> put_flash(:info, "Legacy import done.")
      |> assign(:legacy_import_async_result, AsyncResult.ok(%AsyncResult{}, :ok))

    {:noreply, socket}
  end

  def handle_async(:legacy_import, {:exit, reason}, socket) do
    socket =
      socket
      |> put_flash(:error, "Legacy import failed: #{inspect(reason)}")
      |> assign(:legacy_import_async_result, %AsyncResult{})

    {:noreply, socket}
  end

  def handle_async(:ebird_preload, {:ok, {:ok, ebird_checklists}}, socket) do
    socket =
      socket
      |> put_flash(:info, "eBird preload done.")
      |> assign(:ebird_checklists, ebird_checklists)
      |> assign(:ebird_preload_async_result, AsyncResult.ok(%AsyncResult{}, :ok))

    {:noreply, socket}
  end

  def handle_async(:ebird_preload, {:ok, {:error, reason}}, socket) do
    socket =
      socket
      |> put_flash(:error, "eBird preload failed: #{reason}")
      |> assign(:ebird_preload_async_result, %AsyncResult{})

    {:noreply, socket}
  end

  def handle_async(:ebird_preload, {:exit, reason}, socket) do
    socket =
      socket
      |> put_flash(:error, "eBird preload failed: #{inspect(reason)}")
      |> assign(:ebird_preload_async_result, %AsyncResult{})

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <.h1>Admin Tasks</.h1>
    <.h2>Legacy Import</.h2>
    <CoreComponents.simple_form
      for={nil}
      phx-submit="legacy_import"
      action={~p"/admin/tasks/legacy_import"}
    >
      <:actions>
        <%= if @legacy_import_async_result.loading do %>
          <CoreComponents.button disabled>processing...</CoreComponents.button>
        <% else %>
          <CoreComponents.button>Import</CoreComponents.button>
        <% end %>
      </:actions>
    </CoreComponents.simple_form>

    <.h2>eBird preload</.h2>
    <CoreComponents.simple_form for={nil} phx-submit="ebird_preload">
      <:actions>
        <%= if @ebird_preload_async_result.loading do %>
          <CoreComponents.button disabled>processing...</CoreComponents.button>
        <% else %>
          <CoreComponents.button>Start</CoreComponents.button>
        <% end %>
      </:actions>
    </CoreComponents.simple_form>

    <div>{inspect(@ebird_checklists)}</div>
    """
  end
end
