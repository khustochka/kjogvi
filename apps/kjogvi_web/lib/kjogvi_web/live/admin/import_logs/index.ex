defmodule KjogviWeb.Live.Admin.ImportLogs.Index do
  @moduledoc """
  Admin index of import runs across all users, newest first and paginated,
  with a filter narrowing to runs that need attention (failed or completed
  with unimported rows). Each row links to the run's detail page; a marker
  flags finished runs whose source upload was retained for review.
  """

  use KjogviWeb, :live_view

  import Scrivener.PhoenixView

  alias Kjogvi.Imports
  alias Kjogvi.Imports.ImportLog

  @logs_per_page 50

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Import Logs")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filter = if params["status"] == "issues", do: :issues, else: :all
    page = params |> Map.get("page", "1") |> String.to_integer()

    import_logs =
      Imports.list_import_logs_for_admin(filter, %{page: page, page_size: @logs_per_page})

    {:noreply,
     socket
     |> assign(:filter, filter)
     |> assign(:import_logs, import_logs)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.h1>Import Logs</.h1>

      <nav aria-label="Filter import logs">
        <ul class="flex gap-2">
          <li>
            <.link patch={~p"/admin/import_logs"} class={filter_class(@filter == :all)}>All</.link>
          </li>
          <li>
            <.link
              patch={~p"/admin/import_logs?status=issues"}
              class={filter_class(@filter == :issues)}
              phx-no-format
            >With issues</.link>
          </li>
        </ul>
      </nav>

      <p :if={@import_logs.entries == []} class="text-sm text-stone-500">No import runs.</p>

      <ul :if={@import_logs.entries != []} id="import-logs" class="space-y-2">
        <li
          :for={log <- @import_logs.entries}
          id={"import-log-#{log.id}"}
          class="flex flex-wrap items-baseline gap-x-3 gap-y-1 border border-stone-200 rounded-lg px-4 py-3"
        >
          <span class="text-sm text-stone-500"><.import_time at={log.inserted_at} /></span>
          <span class="font-header font-bold text-forest-800">{log.user.nickname}</span>
          <span class="font-medium">{Kjogvi.Types.ImportSource.label(log.source)}</span>
          <.import_status_badge status={log.status} />
          <span
            :if={ImportLog.finished?(log) && log.upload_key}
            class="text-xs font-medium rounded-full px-2 py-0.5 bg-stone-100 text-stone-600"
          >
            Upload retained
          </span>
          <span :if={import_details(log)} class="text-sm text-stone-600">
            {import_details(log)}
          </span>
          <.link
            navigate={~p"/admin/import_logs/#{log}"}
            class="ml-auto self-center inline-block rounded border border-forest-300 bg-forest-50 px-2 py-0.5 text-xs font-medium text-forest-700 no-underline hover:bg-forest-100"
          >Details</.link>
        </li>
      </ul>

      <div :if={@import_logs.total_pages > 1} class="mt-6">
        {paginate(@socket, @import_logs, paginated_logs_path(@filter), [:index], live: true)}
      </div>
    </div>
    """
  end

  defp filter_class(active) do
    [
      "inline-block rounded-full px-3 py-1 text-sm font-medium no-underline",
      if(active,
        do: "bg-forest-600 text-white",
        else: "bg-stone-100 text-stone-600 hover:bg-stone-200"
      )
    ]
  end

  # Page links carry the filter as a query param so paging preserves it.
  defp paginated_logs_path(filter) do
    fn _conn, _action, page, _params ->
      query = if filter == :issues, do: [status: "issues"], else: []

      case page do
        1 -> ~p"/admin/import_logs?#{query}"
        n -> ~p"/admin/import_logs/page/#{n}?#{query}"
      end
    end
  end
end
