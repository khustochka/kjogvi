defmodule KjogviWeb.Live.My.Imports.Registry do
  @moduledoc """
  Generic task lifecycle plumbing for import LiveComponents.

  Tracks `Task.Supervisor.async_nolink` refs started by child components and
  routes their `{ref, result}` / `{:DOWN, ref, ...}` messages back to the
  originating component via `send_update/2`.

  Children register a started task by sending the LiveView:

      send(self(), {:register_import, __MODULE__, component_id, ref})
  """

  import Phoenix.LiveView, only: [attach_hook: 4, put_private: 3, send_update: 2]

  @private_key __MODULE__

  def on_mount(:attach, _params, _session, socket) do
    socket =
      socket
      |> put_private(@private_key, %{})
      |> attach_hook(:imports_registry_register, :handle_info, &handle_register/2)
      |> attach_hook(:imports_registry_result, :handle_info, &handle_result/2)

    {:cont, socket}
  end

  defp handle_register({:register_import, module, component_id, ref}, socket)
       when is_atom(module) and is_reference(ref) do
    {:halt, put_entry(socket, ref, {module, component_id})}
  end

  defp handle_register(_msg, socket), do: {:cont, socket}

  defp handle_result({ref, {:ok, data}}, socket) when is_reference(ref) do
    case fetch_entry(socket, ref) do
      {:ok, {module, id}} ->
        Process.demonitor(ref, [:flush])
        send_update(module, id: id, status: :ok, data: data)
        {:halt, drop_entry(socket, ref)}

      :error ->
        {:cont, socket}
    end
  end

  defp handle_result({ref, {:error, data}}, socket) when is_reference(ref) do
    case fetch_entry(socket, ref) do
      {:ok, {module, id}} ->
        Process.demonitor(ref, [:flush])
        send_update(module, id: id, status: :error, data: data)
        {:halt, drop_entry(socket, ref)}

      :error ->
        {:cont, socket}
    end
  end

  defp handle_result({:DOWN, ref, :process, _pid, _reason}, socket) when is_reference(ref) do
    case fetch_entry(socket, ref) do
      {:ok, {module, id}} ->
        send_update(module, id: id, status: :error, data: %{message: "Server error."})
        {:halt, drop_entry(socket, ref)}

      :error ->
        {:cont, socket}
    end
  end

  defp handle_result(_msg, socket), do: {:cont, socket}

  defp put_entry(socket, ref, value) do
    put_private(socket, @private_key, Map.put(entries(socket), ref, value))
  end

  defp fetch_entry(socket, ref), do: Map.fetch(entries(socket), ref)

  defp drop_entry(socket, ref) do
    put_private(socket, @private_key, Map.delete(entries(socket), ref))
  end

  defp entries(socket), do: socket.private[@private_key] || %{}
end
