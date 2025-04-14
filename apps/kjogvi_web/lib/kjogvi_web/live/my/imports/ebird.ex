defmodule KjogviWeb.Live.My.Imports.Ebird do
  @moduledoc """
  eBird preload live component.
  """

  use KjogviWeb, :live_component

  alias Phoenix.LiveView.AsyncResult
  alias Kjogvi.Ebird

  def mount(socket) do
    {
      :ok,
      socket
      |> assign(:async_result, %AsyncResult{})
      |> assign(:ebird_checklists, [])
    }
  end

  def update(%{user: user}, socket) do
    {
      :ok,
      socket
      |> assign(:user, user)
    }
  end

  def handle_event("start_preload", _params, socket) do
    {:noreply,
     socket
     |> clear_flash()
     |> put_flash(:info, "eBird import in progress...")
     |> assign(:ebird_checklists, [])
     |> start_ebird_preload()}
  end

  defp start_ebird_preload(%{assigns: %{user: user}} = socket) do
    socket
    |> assign(:async_result, AsyncResult.loading())
    |> start_async(:ebird_preload, fn ->
      Ebird.Web.preload_new_checklists_for_user(user)
    end)
  end

  def handle_async(:ebird_preload, {:ok, {:ok, ebird_checklists}}, socket) do
    socket =
      socket
      |> clear_flash()
      |> put_flash(:info, "eBird preload done.")
      |> assign(:ebird_checklists, ebird_checklists)
      |> assign(:async_result, AsyncResult.ok(%AsyncResult{}, :ok))

    {:noreply, socket}
  end

  def handle_async(:ebird_preload, {:ok, {:error, reason}}, socket) do
    socket =
      socket
      |> clear_flash()
      |> put_flash(:error, "eBird preload failed: #{reason}")
      |> assign(:async_result, %AsyncResult{})

    {:noreply, socket}
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
      <CoreComponents.simple_form for={nil} phx-submit="start_preload" phx-target={@myself}>
        <:actions>
          <%= if @async_result.loading do %>
            <CoreComponents.button disabled>Preload</CoreComponents.button>
          <% else %>
            <CoreComponents.button>Preload</CoreComponents.button>
          <% end %>
        </:actions>
      </CoreComponents.simple_form>

      <div class="my-4">{inspect(@ebird_checklists)}</div>
    </div>
    """
  end
end
