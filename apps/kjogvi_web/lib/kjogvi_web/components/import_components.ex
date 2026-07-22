defmodule KjogviWeb.ImportComponents do
  @moduledoc """
  Presentation of `Kjogvi.Imports.ImportLog` runs — timestamp, status badge,
  and the one-line outcome details — shared by the user-facing import history
  and the admin import logs.
  """

  use Phoenix.Component

  alias Kjogvi.Imports.ImportLog

  attr :at, DateTime, required: true

  def import_time(assigns) do
    ~H"""
    <time datetime={DateTime.to_iso8601(@at)}>{Calendar.strftime(@at, "%-d %b %Y %H:%M")}</time>
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

    Enum.join([imported | issue_details(summary)], "; ")
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
  defp count_noun(count, singular, nil), do: "#{count} #{singular}s"
  defp count_noun(count, _singular, plural), do: "#{count} #{plural}"
end
