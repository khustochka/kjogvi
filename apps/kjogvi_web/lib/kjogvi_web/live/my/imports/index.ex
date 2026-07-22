defmodule KjogviWeb.Live.My.Imports.Index do
  @moduledoc """
  The user's import tasks and the history of their import runs.

  The history reloads on the import jobs' lifecycle broadcasts (this LV's
  refresh hook is attached before the task components' hooks, which halt
  those messages) and on `:refresh_import_logs` sent by a component right
  after it enqueues a run.
  """

  use KjogviWeb, :live_view

  alias Kjogvi.Accounts
  alias Kjogvi.Imports.ImportLog
  alias KjogviWeb.Live.My.Imports

  on_mount {__MODULE__, :import_log_refresh}
  on_mount {Imports.Legacy, :attach}
  on_mount {Imports.Ebird, :attach}
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
    assign(socket, :import_logs, Kjogvi.Imports.list_import_logs(scope.current_user))
  end

  def mount(_params, _session, %{assigns: assigns} = socket) do
    {:ok,
     socket
     |> assign(:page_title, "Import Tasks")
     |> assign(
       :imports,
       Enum.filter(imports(), fn {_, _, _, condition_func} ->
         condition_func.(assigns.current_scope.current_user)
       end)
     )
     |> reload_import_logs()}
  end

  def render(assigns) do
    ~H"""
    <.h1>Import Tasks</.h1>

    <div class="lg:grid lg:grid-cols-2 lg:gap-6 lg:items-start">
      <div
        :for={{module, header, id, _} <- @imports}
        class="border border-slate-300 rounded-lg p-6 mb-8 lg:mb-0"
      >
        <.h2 class="mb-4!">{header}</.h2>
        <.live_component module={module} user={@current_scope.current_user} id={id} />
      </div>
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
          <span class="text-sm text-stone-500">
            <time datetime={DateTime.to_iso8601(log.inserted_at)}>
              {Calendar.strftime(log.inserted_at, "%-d %b %Y %H:%M")}
            </time>
          </span>
          <span class="font-medium">{Kjogvi.Types.ImportSource.label(log.source)}</span>
          <span class={[
            "text-xs font-medium rounded-full px-2 py-0.5",
            status_class(log.status)
          ]}>
            {status_label(log.status)}
          </span>
          <span :if={details(log) != nil} class="text-sm text-stone-600">{details(log)}</span>
        </li>
      </ul>
    </section>
    """
  end

  defp imports do
    [
      {Imports.Legacy, "Legacy Import", "legacy-import", fn user -> Accounts.admin?(user) end},
      {Imports.Ebird, "eBird preload", "ebird-import", fn _ -> true end},
      {Imports.EbirdCsv, "eBird CSV import", "ebird-csv-import", fn _ -> true end}
    ]
  end

  defp status_label(:queued), do: "Queued"
  defp status_label(:running), do: "Running"
  defp status_label(:completed), do: "Completed"
  defp status_label(:completed_with_errors), do: "Completed with issues"
  defp status_label(:failed), do: "Failed"

  defp status_class(:queued), do: "bg-stone-100 text-stone-600"
  defp status_class(:running), do: "bg-sky-100 text-sky-700"
  defp status_class(:completed), do: "bg-forest-100 text-forest-700"
  defp status_class(:completed_with_errors), do: "bg-amber-100 text-amber-700"
  defp status_class(:failed), do: "bg-rose-100 text-rose-700"

  defp details(%ImportLog{status: :failed, error: error}), do: error

  defp details(%ImportLog{status: status, summary: summary})
       when status in [:completed, :completed_with_errors] do
    imported =
      "#{count_noun(count(summary, "checklists_created"), "checklist")} and " <>
        "#{count_noun(count(summary, "observations_created"), "observation")} imported"

    Enum.join([imported | issue_details(summary)], "; ")
  end

  defp details(_log), do: nil

  defp issue_details(summary) do
    not_imported =
      count(summary, "checklists_invalid") + count(summary, "checklists_unmapped") +
        count(summary, "checklists_failed")

    unrecognized = summary |> Map.get("unresolved_taxa", []) |> length()

    Enum.reject(
      [
        not_imported > 0 && "#{count_noun(not_imported, "checklist")} not imported",
        unrecognized > 0 && "#{count_noun(unrecognized, "taxon", "taxa")} unrecognized"
      ],
      &(&1 == false)
    )
  end

  # Summaries are JSONB written by each import kind, so read them tolerantly.
  defp count(summary, key), do: Map.get(summary, key, 0)

  defp count_noun(count, singular, plural \\ nil)
  defp count_noun(1, singular, _plural), do: "1 #{singular}"
  defp count_noun(count, singular, nil), do: "#{count} #{singular}s"
  defp count_noun(count, _singular, plural), do: "#{count} #{plural}"
end
