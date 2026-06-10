defmodule KjogviWeb.Live.Admin.ExclusiveTasks.Index do
  @moduledoc """
  Admin dashboard listing every task tracked by
  `Kjogvi.Server.ExclusiveTaskProcessor`, updated live over PubSub.

  On mount it seeds a stream from `ExclusiveTaskProcessor.list_statuses/0` and
  subscribes to `ExclusiveTaskProcessor.lifecycle_topic/0`. Each
  `{:lifecycle, event, key, async_result}` event upserts the corresponding row
  (the stream id is derived from the key, so the same key updates in place),
  covering start, mid-task progress, and ok/error completion.
  """

  use KjogviWeb, :live_view

  alias Kjogvi.Server.ExclusiveTaskProcessor
  alias Kjogvi.Util.PubSubTopic

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Kjogvi.PubSub, ExclusiveTaskProcessor.lifecycle_topic())
    end

    rows =
      ExclusiveTaskProcessor.list_statuses()
      |> Enum.map(fn {key, async_result} -> row(key, async_result) end)

    {:ok,
     socket
     |> assign(:page_title, "Exclusive Tasks")
     |> assign_counts(rows)
     |> stream(:tasks, rows)}
  end

  # Lifecycle (and mirrored progress) events carry the AsyncResult exactly as the
  # processor stores it; upsert the row by its stable id and refresh the counts.
  @impl true
  def handle_info({:lifecycle, _event, key, async_result}, socket) do
    row = row(key, async_result)

    {:noreply,
     socket
     |> stream_insert(:tasks, row)
     |> bump_counts(row)}
  end

  # Builds a flat, stream-friendly row from a key + AsyncResult. The id is the
  # stringified key (`PubSubTopic.for_key/1`), which is stable per key so repeated
  # events for the same task update the same row rather than appending.
  defp row(key, async_result) do
    label = PubSubTopic.for_key(key)

    %{
      # `:` is not valid in a CSS id selector, so sanitize the topic for the DOM
      # id while keeping the readable form for display. The stream prefixes this
      # with `tasks-`, yielding e.g. `tasks-legacy_import-1`.
      id: String.replace(label, ~r/[^A-Za-z0-9_-]/, "-"),
      key: label,
      state: state(async_result),
      message: message(async_result)
    }
  end

  defp state(%{failed: failed}) when not is_nil(failed), do: :failed
  defp state(%{loading: loading}) when not is_nil(loading), do: :loading
  defp state(%{ok?: true}), do: :ok
  defp state(_), do: :unknown

  defp message(%{failed: failed}) when not is_nil(failed),
    do: result_message(failed, "Server error.")

  defp message(%{loading: loading}) when not is_nil(loading),
    do: result_message(loading, "In progress...")

  defp message(%{ok?: true, result: result}), do: result_message(result, "Done.")
  defp message(_), do: ""

  defp result_message(%{message: message}, _default), do: message
  defp result_message(:timeout, _default), do: "Timeout"
  defp result_message(:malformed_result, _default), do: "Malformed result"
  defp result_message(other, _default) when is_binary(other), do: other
  defp result_message(other, _default) when is_atom(other), do: to_string(other)
  defp result_message(_other, default), do: default

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

    <p class="mb-6 text-slate-600" aria-live="polite">
      {@loading_count} running · {@total_count} tracked
    </p>

    <ul
      id="exclusive-tasks"
      phx-update="stream"
      role="list"
      class="divide-y divide-slate-200 border border-slate-200 rounded-lg"
    >
      <li id="exclusive-tasks-empty" class="hidden only:block p-6 text-slate-500 italic">
        No tasks tracked.
      </li>
      <li
        :for={{dom_id, task} <- @streams.tasks}
        id={dom_id}
        class="flex flex-col gap-1 p-4 sm:flex-row sm:items-center sm:justify-between sm:gap-4"
      >
        <div class="flex items-center gap-3 min-w-0">
          <.state_badge state={task.state} />
          <span class="font-mono text-sm truncate" title={task.key}>{task.key}</span>
        </div>
        <span class="text-sm text-slate-600 sm:text-right sm:max-w-1/2 break-words">
          {task.message}
        </span>
      </li>
    </ul>
    """
  end

  attr :state, :atom, required: true

  defp state_badge(assigns) do
    {label, classes} =
      case assigns.state do
        :loading -> {"running", "bg-blue-100 text-blue-800"}
        :ok -> {"ok", "bg-green-100 text-green-800"}
        :failed -> {"failed", "bg-red-100 text-red-800"}
        _ -> {"unknown", "bg-slate-100 text-slate-800"}
      end

    assigns = assign(assigns, label: label, classes: classes)

    ~H"""
    <span class={[
      "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium shrink-0",
      @classes
    ]}>
      {@label}
    </span>
    """
  end
end
