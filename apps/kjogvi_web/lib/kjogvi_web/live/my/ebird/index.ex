defmodule KjogviWeb.Live.My.Ebird.Index do
  @moduledoc """
  The user's eBird import page: uploading an eBird export and the history of
  their eBird import runs.

  The history reloads on the import job's lifecycle broadcasts (this LV's
  refresh hook is attached before the task component's hook, which halts those
  messages) and on `:refresh_import_logs` sent by the component right after it
  enqueues a run.
  """

  use KjogviWeb, :live_view

  alias KjogviWeb.Live.My.Imports

  on_mount {__MODULE__, :import_log_refresh}
  on_mount {Imports.EbirdCsv, :attach}

  def on_mount(:import_log_refresh, _params, _session, socket) do
    {:cont, attach_hook(socket, :import_log_refresh, :handle_info, &handle_refresh/2)}
  end

  defp handle_refresh(:refresh_import_logs, socket) do
    {:halt, reload_import_logs(socket)}
  end

  defp handle_refresh({:lifecycle, _event, {:ebird_import, _user_id}, _result}, socket) do
    {:cont, reload_import_logs(socket)}
  end

  defp handle_refresh(_msg, socket), do: {:cont, socket}

  defp reload_import_logs(%{assigns: %{current_scope: scope}} = socket) do
    assign(
      socket,
      :import_logs,
      Kjogvi.Imports.list_import_logs(scope.current_user, source: :ebird)
    )
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "eBird Import")
     |> reload_import_logs()}
  end

  def render(assigns) do
    ~H"""
    <.h1>eBird Import</.h1>

    <div class="border border-slate-300 rounded-lg p-6 mb-8 lg:max-w-2xl">
      <.live_component
        module={Imports.EbirdCsv}
        user={@current_scope.current_user}
        id="ebird-csv-import"
      />
    </div>

    <section id="import-history" class="mt-10">
      <.h2>Import History</.h2>

      <p :if={@import_logs == []} class="text-sm text-stone-500">No imports yet.</p>

      <ul :if={@import_logs != []} class="space-y-2">
        <li
          :for={log <- @import_logs}
          id={"import-log-#{log.id}"}
          class="flex flex-wrap items-baseline gap-x-3 gap-y-1 border border-stone-200 rounded-lg px-4 py-3"
        >
          <span class="text-sm text-stone-500"><.import_time at={log.inserted_at} /></span>
          <.import_status_badge status={log.status} />
          <span :if={import_details(log)} class="text-sm text-stone-600">
            {import_details(log)}
          </span>
        </li>
      </ul>
    </section>
    """
  end
end
