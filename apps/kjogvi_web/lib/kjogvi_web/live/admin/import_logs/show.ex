defmodule KjogviWeb.Live.Admin.ImportLogs.Show do
  @moduledoc """
  One import run for admin review: who ran it and how it ended, a download
  link for the source upload while it is still stored, and the recorded
  failed rows with their raw data, paginated.
  """

  use KjogviWeb, :live_view

  import Scrivener.PhoenixView

  alias Kjogvi.Imports

  @errors_per_page 25

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _uri, socket) do
    import_log = Imports.get_import_log!(id)
    page = params |> Map.get("page", "1") |> String.to_integer()

    errors =
      Imports.paginate_import_errors(import_log.id, %{page: page, page_size: @errors_per_page})

    {:noreply,
     socket
     |> assign(:page_title, "Import Log ##{import_log.id}")
     |> assign(:import_log, import_log)
     |> assign(:errors, errors)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.h1>Import Log #{@import_log.id}</.h1>

      <dl id="import-log-facts" class="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1 text-sm">
        <dt class="text-stone-500">User</dt>
        <dd>{@import_log.user.nickname}</dd>
        <dt class="text-stone-500">Source</dt>
        <dd>{Kjogvi.Types.ImportSource.label(@import_log.source)}</dd>
        <dt class="text-stone-500">Status</dt>
        <dd><.import_status_badge status={@import_log.status} /></dd>
        <dt class="text-stone-500">Enqueued</dt>
        <dd><.import_time at={@import_log.inserted_at} /></dd>
        <dt :if={@import_log.started_at} class="text-stone-500">Started</dt>
        <dd :if={@import_log.started_at}><.import_time at={@import_log.started_at} /></dd>
        <dt :if={@import_log.finished_at} class="text-stone-500">Finished</dt>
        <dd :if={@import_log.finished_at}><.import_time at={@import_log.finished_at} /></dd>
        <dt :if={import_details(@import_log)} class="text-stone-500">Outcome</dt>
        <dd :if={import_details(@import_log)} class="whitespace-pre-wrap">
          {import_details(@import_log)}
        </dd>
        <dt :if={@import_log.upload_key} class="text-stone-500">Source file</dt>
        <dd :if={@import_log.upload_key}>
          <.link href={~p"/admin/import_logs/#{@import_log}/upload"}>Download</.link>
        </dd>
      </dl>

      <p :if={@import_log.summary["errors_truncated"]} class="text-sm text-amber-700">
        The recorded rows were capped; the retained source file is the complete record.
      </p>

      <section id="import-errors">
        <.h2>Failed Rows</.h2>

        <p :if={@errors.total_entries == 0} class="text-sm text-stone-500">
          No failed rows recorded for this run.
        </p>

        <ul :if={@errors.entries != []} class="space-y-4">
          <li
            :for={error <- @errors.entries}
            id={"import-error-#{error.id}"}
            class="border border-stone-200 rounded-lg p-4"
          >
            <div class="flex flex-wrap items-baseline gap-x-3 gap-y-1">
              <span class="text-xs font-medium rounded-full px-2 py-0.5 bg-stone-100 text-stone-600">
                {category_label(error.category)}
              </span>
              <span :if={error.submission_id} class="font-mono text-sm">{error.submission_id}</span>
            </div>
            <pre
              :if={error.error}
              class="mt-2 text-sm text-rose-700 whitespace-pre-wrap"
            >{error.error}</pre>
            <div :if={error.rows != []} class="mt-3 overflow-x-auto">
              <table class="min-w-full text-left text-xs">
                <thead>
                  <tr>
                    <th :for={col <- columns(error.rows)} class="px-2 py-1 font-semibold">
                      {col}
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={row <- error.rows} class="border-t border-stone-100 align-top">
                    <td :for={col <- columns(error.rows)} class="px-2 py-1">{row[col]}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </li>
        </ul>

        <div :if={@errors.total_pages > 1} class="mt-6">
          {paginate(@socket, @errors, paginated_errors_path(@import_log), [:show], live: true)}
        </div>
      </section>
    </div>
    """
  end

  defp category_label(:invalid), do: "Invalid submission"
  defp category_label(:unmapped), do: "Location unmapped"
  defp category_label(:failed), do: "Checklist rejected"
  defp category_label(:unresolved_taxa), do: "Unresolved taxa"

  # Rows are JSONB maps, so the CSV's column order is lost — sort for a
  # stable table.
  defp columns(rows) do
    rows |> Enum.flat_map(&Map.keys/1) |> Enum.uniq() |> Enum.sort()
  end

  defp paginated_errors_path(import_log) do
    fn _conn, _action, page, _params ->
      case page do
        1 -> ~p"/admin/import_logs/#{import_log}"
        n -> ~p"/admin/import_logs/#{import_log}?#{[page: n]}"
      end
    end
  end
end
