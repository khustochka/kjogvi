defmodule KjogviWeb.DefaultMounts do
  @moduledoc false

  def on_mount(:default, _params, _session, socket) do
    socket = mount_private_view(socket, false)

    {:cont, socket}
  end

  def on_mount(:private_view, _params, _session, socket) do
    socket = mount_private_view(socket, true)

    {:cont, socket}
  end

  defp mount_private_view(socket, value) do
    Phoenix.Component.assign(socket, :private_view, value)
  end
end
