defmodule KjogviWeb.Live.Admin.ExclusiveTasks.Index do
  @moduledoc """
  Admin dashboard listing every task tracked by
  `Kjogvi.Server.ExclusiveTaskProcessor`, updated live over PubSub.

  On mount it seeds a stream from `ExclusiveTaskProcessor.list_statuses/0` and
  subscribes to `ExclusiveTaskProcessor.lifecycle_topic/0`. Each
  `{:lifecycle, event, key, async_result}` event upserts the corresponding row
  (the stream id is derived from the key, so the same key updates in place),
  covering start, mid-task progress, and ok/error completion.

  Each row also shows the time the task finished. The finish time is stamped from
  the event itself (`DateTime.utc_now/0` when the ok/error lifecycle arrives), so
  tasks that were already finished when the dashboard mounted have no recorded
  finish time.

  The details cell shows the status's raw value inspected verbatim — the task's
  result, the failure reason, or the loading state — flattened to one truncated
  line. Clicking it expands the full, pretty-inspected term in place via a
  client-side `JS.toggle/1`, with no server round-trip.
  """

  use KjogviWeb, :live_view

  alias Kjogvi.Server.ExclusiveTaskProcessor
  alias Kjogvi.Util.PubSubTopic
  alias Phoenix.LiveView.JS

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Kjogvi.PubSub, ExclusiveTaskProcessor.lifecycle_topic())
    end

    rows =
      ExclusiveTaskProcessor.list_statuses()
      |> Enum.map(fn {key, async_result} -> row(key, async_result, []) end)

    {:ok,
     socket
     |> assign(:page_title, "Exclusive Tasks")
     |> assign(:container_class, "max-w-7xl")
     |> assign_counts(rows)
     |> stream(:tasks, rows)}
  end

  # Lifecycle (and mirrored progress) events carry the AsyncResult exactly as the
  # processor stores it; upsert the row by its stable id and refresh the counts.
  # A terminal event stamps the finish time straight from the wall clock.
  @impl true
  def handle_info({:lifecycle, event, key, async_result}, socket) do
    finished_at = if event in [:ok, :error], do: DateTime.utc_now()
    row = row(key, async_result, finished_at: finished_at)

    {:noreply,
     socket
     |> stream_insert(:tasks, row)
     |> bump_counts(row)}
  end

  # Builds a flat, stream-friendly row from a key + AsyncResult. The id is the
  # stringified key (`PubSubTopic.for_key/1`), which is stable per key so repeated
  # events for the same task update the same row rather than appending.
  #
  # `:finished_at` comes from the caller, since the AsyncResult doesn't carry it:
  # the finish time is stamped from the lifecycle event. It is absent for tasks
  # that haven't finished within this dashboard's lifetime.
  defp row(key, async_result, opts) do
    label = PubSubTopic.for_key(key)

    %{
      # `:` is not valid in a CSS id selector, so sanitize the topic for the DOM
      # id while keeping the readable form for display. The stream prefixes this
      # with `tasks-`, yielding e.g. `tasks-legacy_import-1`.
      id: String.replace(label, ~r/[^A-Za-z0-9_-]/, "-"),
      key: label,
      state: state(async_result),
      details: details(async_result, pretty: true),
      details_summary: details(async_result, pretty: false),
      finished_at: Keyword.get(opts, :finished_at)
    }
  end

  defp format_finished_at(%DateTime{} = at), do: Calendar.strftime(at, "%Y-%m-%d %H:%M:%S UTC")

  defp state(%{failed: failed}) when not is_nil(failed), do: :failed
  defp state(%{loading: loading}) when not is_nil(loading), do: :loading
  defp state(%{ok?: true}), do: :ok
  defp state(_), do: :unknown

  # The raw value carried by the status, inspected verbatim — whatever the task
  # returned (or the failure reason / loading state). `pretty: true` is the
  # multi-line form shown when expanded; `pretty: false` is the flattened
  # single-line form used in the truncated cell. `nil` means there's nothing to
  # show (an untracked / blank status).
  defp details(%{failed: failed}, opts) when not is_nil(failed), do: inspect_value(failed, opts)
  defp details(%{ok?: true, result: result}, opts), do: inspect_value(result, opts)

  defp details(%{loading: loading}, opts) when not is_nil(loading),
    do: inspect_value(loading, opts)

  defp details(_, _opts), do: nil

  defp inspect_value(term, opts),
    do: inspect(term, pretty: Keyword.fetch!(opts, :pretty), limit: :infinity)

  # Counts are tracked separately from the stream, which is not enumerable.
  defp assign_counts(socket, rows) do
    socket
    |> assign(:loading_count, Enum.count(rows, &(&1.state == :loading)))
    |> assign(:total_count, length(rows))
    |> assign(:seen_ids, MapSet.new(Enum.map(rows, & &1.id)))
    |> assign(:loading_ids, loading_ids(rows))
  end

  defp loading_ids(rows) do
    rows
    |> Enum.filter(&(&1.state == :loading))
    |> Enum.map(& &1.id)
    |> MapSet.new()
  end

  # Recomputes the counts on each event without re-reading the whole stream:
  # track the set of seen ids (total) and the set of currently-loading ids.
  defp bump_counts(socket, %{id: id, state: state}) do
    seen_ids = MapSet.put(socket.assigns.seen_ids, id)

    loading_ids =
      if state == :loading do
        MapSet.put(socket.assigns.loading_ids, id)
      else
        MapSet.delete(socket.assigns.loading_ids, id)
      end

    socket
    |> assign(:seen_ids, seen_ids)
    |> assign(:loading_ids, loading_ids)
    |> assign(:total_count, MapSet.size(seen_ids))
    |> assign(:loading_count, MapSet.size(loading_ids))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.h1>Exclusive Tasks</.h1>

    <p class="mb-4 font-mono text-sm text-slate-600" aria-live="polite">
      {@loading_count} running, {@total_count} tracked
    </p>

    <%!-- Plain admin/process-list table: dense monospace rows, scrolls sideways on
    narrow screens rather than reflowing. The stream lives on <tbody>. --%>
    <div class="overflow-x-auto border border-slate-300">
      <table class="w-full min-w-3xl table-fixed border-collapse font-mono text-sm">
        <thead>
          <tr class="border-b border-slate-300 bg-slate-100 text-left text-slate-600">
            <th scope="col" class="w-24 px-3 py-1.5 font-semibold">STATUS</th>
            <th scope="col" class="w-64 px-3 py-1.5 font-semibold">KEY</th>
            <th scope="col" class="px-3 py-1.5 font-semibold">DETAILS</th>
            <th scope="col" class="w-48 px-3 py-1.5 font-semibold">FINISHED</th>
          </tr>
        </thead>
        <tbody id="exclusive-tasks" phx-update="stream">
          <tr id="exclusive-tasks-empty" class="hidden only:table-row">
            <td colspan="4" class="px-3 py-2 italic text-slate-500">No tasks tracked.</td>
          </tr>
          <tr
            :for={{dom_id, task} <- @streams.tasks}
            id={dom_id}
            class="border-b border-slate-200 last:border-0 even:bg-slate-50"
          >
            <td class={["px-3 py-1.5 align-top", state_class(task.state)]}>
              {state_label(task.state)}
            </td>
            <td class="truncate px-3 py-1.5 align-top text-slate-800" title={task.key}>{task.key}</td>
            <td class="px-3 py-1.5 align-top text-slate-600">
              <span :if={!task.details} class="text-slate-300">—</span>
              <%!-- A button toggles the one-line truncated value for the full,
              pre-formatted term. Pure client-side JS.toggle, so it survives stream
              re-renders without server round-trips. --%>
              <button
                :if={task.details}
                type="button"
                class="flex w-full items-start gap-1 text-left hover:text-slate-900"
                phx-click={JS.toggle(to: "##{dom_id}-summary") |> JS.toggle(to: "##{dom_id}-full")}
                aria-label="Toggle full details"
              >
                <span class="select-none text-slate-400">▸</span>
                <span
                  id={"#{dom_id}-summary"}
                  class="block min-w-0 flex-1 truncate"
                  title={task.details_summary}
                >
                  {task.details_summary}
                </span>
                <pre
                  id={"#{dom_id}-full"}
                  class="hidden min-w-0 flex-1 whitespace-pre-wrap break-all text-xs text-slate-700"
                >{task.details}</pre>
              </button>
            </td>
            <td class="px-3 py-1.5 text-xs whitespace-nowrap text-slate-500">
              <time :if={task.finished_at} datetime={DateTime.to_iso8601(task.finished_at)}>
                {format_finished_at(task.finished_at)}
              </time>
              <span :if={!task.finished_at} class="text-slate-300">—</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  defp state_label(:loading), do: "RUNNING"
  defp state_label(:ok), do: "OK"
  defp state_label(:failed), do: "FAILED"
  defp state_label(_), do: "UNKNOWN"

  defp state_class(:loading), do: "text-blue-700"
  defp state_class(:ok), do: "text-green-700"
  defp state_class(:failed), do: "font-semibold text-red-700"
  defp state_class(_), do: "text-slate-500"
end
