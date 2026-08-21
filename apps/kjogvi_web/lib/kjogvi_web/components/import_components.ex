defmodule KjogviWeb.ImportComponents do
  @moduledoc """
  Presentation of `Kjogvi.Imports.ImportLog` runs — timestamp, status badge,
  and the one-line outcome details — shared by the user-facing import history
  and the admin import logs.
  """

  use Phoenix.Component

  import KjogviWeb.IconComponents

  alias Kjogvi.Imports.ImportLog
  alias Kjogvi.Util.Number

  @doc """
  The state of a user's import task: a spinner and the job's own progress
  message while a run is in flight, otherwise the outcome of their last run.

  Renders nothing for a user who has never run an import and has none running.
  """
  attr :id, :string, required: true
  attr :running, :string, default: nil, doc: "progress message of the in-flight run, if any"
  attr :failure, :string, default: nil, doc: "message of a run that failed to start or crashed"
  attr :last_run, ImportLog, default: nil

  def import_status(assigns) do
    ~H"""
    <div id={@id} role="status" aria-live="polite">
      <.import_status_line
        :if={@running}
        kind={:running}
        title={@running}
        started_at={running_started_at(@last_run)}
      />

      <.import_status_line
        :if={!@running && @failure}
        kind={:failed}
        title="Import failed"
        detail={@failure}
      />

      <.import_status_line
        :if={!@running && !@failure && @last_run}
        kind={@last_run.status}
        title={last_run_title(@last_run)}
        detail={import_details(@last_run)}
        started_at={@last_run.started_at}
        finished_at={@last_run.finished_at}
      />
    </div>
    """
  end

  # While a run is in flight `last_run` is that run itself, so its start time is
  # available; guard on the status because a job slot can briefly report loading
  # while `last_run` is still a previous, finished run.
  defp running_started_at(%ImportLog{status: :running, started_at: started_at}), do: started_at
  defp running_started_at(_last_run), do: nil

  attr :kind, :atom, required: true
  attr :title, :string, required: true
  attr :detail, :string, default: nil
  attr :started_at, DateTime, default: nil
  attr :finished_at, DateTime, default: nil

  defp import_status_line(assigns) do
    ~H"""
    <div class={["mb-4 flex items-start gap-2.5 rounded-lg px-4 py-3", status_panel_class(@kind)]}>
      <.icon
        :if={@kind == :running}
        name="hero-arrow-path"
        class="mt-0.5 h-5 w-5 shrink-0 animate-spin"
      />
      <.icon
        :if={@kind in [:completed, :completed_with_errors]}
        name="hero-check-circle"
        class="mt-0.5 h-5 w-5 shrink-0"
      />
      <.icon
        :if={@kind == :failed}
        name="hero-exclamation-circle"
        class="mt-0.5 h-5 w-5 shrink-0"
      />
      <.icon :if={@kind == :queued} name="hero-clock" class="mt-0.5 h-5 w-5 shrink-0" />

      <div class="min-w-0">
        <p class="text-sm font-medium">{@title}</p>
        <p :if={@detail} class="mt-0.5 text-sm">{@detail}</p>
        <p :if={@kind == :completed_with_errors} class="mt-0.5 text-sm">
          The items that couldn't be imported have been saved and may be imported later, once the issue is sorted out. Nothing you need to do.
        </p>
        <p :if={@finished_at} class="mt-0.5 text-sm opacity-80">
          <.import_time_ago at={@finished_at} prefix="Finished" />
        </p>
        <p :if={!@finished_at && @started_at} class="mt-0.5 text-sm opacity-80">
          <.import_time_ago at={@started_at} prefix="Started" />
        </p>
      </div>
    </div>
    """
  end

  # A queued run has not started yet, so it reads as pending rather than as an
  # outcome; everything else is reported in the past tense.
  defp last_run_title(%ImportLog{status: :queued}), do: "Import queued"
  defp last_run_title(%ImportLog{status: :running}), do: "Import in progress..."
  defp last_run_title(%ImportLog{status: :completed}), do: "Import complete"

  defp last_run_title(%ImportLog{status: :completed_with_errors}),
    do: "Import finished with issues"

  defp last_run_title(%ImportLog{status: :failed}), do: "Import failed"

  defp status_panel_class(:running), do: "bg-sky-50 text-sky-800"
  defp status_panel_class(:queued), do: "bg-stone-100 text-stone-700"
  defp status_panel_class(:completed), do: "bg-forest-50 text-forest-800"
  defp status_panel_class(:completed_with_errors), do: "bg-amber-50 text-amber-800"
  defp status_panel_class(:failed), do: "bg-rose-50 text-rose-900"

  attr :at, DateTime, required: true

  def import_time(assigns) do
    ~H"""
    <time datetime={DateTime.to_iso8601(@at)}>{Calendar.strftime(@at, "%-d %b %Y %H:%M")}</time>
    """
  end

  attr :at, DateTime, required: true
  attr :prefix, :string, required: true

  # A relative "N minutes ago" line; the exact UTC time is kept in the `title`
  # for anyone who needs it, but the visible text avoids a bare UTC stamp.
  def import_time_ago(assigns) do
    ~H"""
    {@prefix}
    <time datetime={DateTime.to_iso8601(@at)} title={Calendar.strftime(@at, "%-d %b %Y %H:%M UTC")}>
      {Kjogvi.Util.Time.relative(@at)}
    </time>
    """
  end

  attr :status, :atom, required: true

  def import_status_badge(assigns) do
    ~H"""
    <span class={["text-xs font-medium rounded-full px-2 py-0.5", status_class(@status)]}>
      {status_label(@status)}
    </span>
    """
  end

  @doc """
  A one-line account of the run's outcome: counts for a finished run, the
  failure reason for a failed one, `nil` while it hasn't finished.
  """
  def import_details(%ImportLog{status: :failed, error: error}), do: error

  def import_details(%ImportLog{status: status, summary: summary})
      when status in [:completed, :completed_with_errors] do
    imported =
      "#{count_noun(count(summary, "checklists_created"), "checklist")} and " <>
        "#{count_noun(count(summary, "observations_created"), "observation")} imported"

    updated =
      case count(summary, "checklists_updated") do
        0 -> []
        n -> ["#{count_noun(n, "checklist")} updated"]
      end

    Enum.join([imported | updated] ++ issue_details(summary), "; ")
  end

  def import_details(_log), do: nil

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
  defp count_noun(count, singular, nil), do: "#{Number.delimit(count)} #{singular}s"
  defp count_noun(count, _singular, plural), do: "#{Number.delimit(count)} #{plural}"
end
