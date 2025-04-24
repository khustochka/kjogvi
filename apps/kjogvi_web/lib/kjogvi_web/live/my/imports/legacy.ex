defmodule KjogviWeb.Live.My.Imports.Legacy do
  @moduledoc """
  Legacy import live component.
  """

  use KjogviWeb, :live_component

  alias Phoenix.LiveView.AsyncResult

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

  def update(%{source: :legacy_import_progress, message: message}, socket) do
    {:ok,
     socket
     |> put_flash(:info, message)}
  end

  def handle_event("start_import", _params, socket) do
    {:noreply,
     socket
     |> start_import()}
  end

  defp start_import(%{assigns: %{user: user}} = socket) do
    import_id = Ecto.UUID.generate()
    Kjogvi.Legacy.Import.subscribe_progress(import_id)

    socket
    |> clear_flash()
    |> assign(:async_result, AsyncResult.loading())
    |> put_flash(:info, "Legacy import in progress...")
    |> start_async(:legacy_import, fn ->
      Kjogvi.Legacy.Import.run(user, import_id: import_id)
      :ok
    end)
  end

  def handle_async(:legacy_import, {:ok, :ok = _success_result}, socket) do
    socket =
      socket
      |> clear_flash()
      |> put_flash(:info, "Legacy import done.")
      |> assign(:async_result, AsyncResult.ok(%AsyncResult{}, :ok))

    {:noreply, socket}
  end

  def handle_async(:legacy_import, {:exit, _reason}, socket) do
    socket =
      socket
      |> clear_flash()
      |> put_flash(:error, "Legacy import failed: Server error.")
      |> assign(:async_result, %AsyncResult{})

    {:noreply, socket}
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
