defmodule KjogviWeb.ImportComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Kjogvi.Imports.ImportLog
  alias KjogviWeb.ImportComponents

  defp completed(summary, status \\ :completed) do
    %ImportLog{status: status, summary: summary}
  end

  describe "import_details/1" do
    test "groups large counts in threes" do
      details =
        completed(%{"checklists_created" => 12_433, "observations_created" => 84_123})
        |> ImportComponents.import_details()

      assert details == "12,433 checklists and 84,123 observations imported"
    end

    test "leaves counts under a thousand alone" do
      details =
        completed(%{"checklists_created" => 3, "observations_created" => 12})
        |> ImportComponents.import_details()

      assert details == "3 checklists and 12 observations imported"
    end

    test "a count of one stays singular" do
      details =
        completed(%{"checklists_created" => 1, "observations_created" => 1})
        |> ImportComponents.import_details()

      assert details == "1 checklist and 1 observation imported"
    end

    test "delimits the counts in the issue details too" do
      details =
        completed(
          %{
            "checklists_created" => 0,
            "observations_created" => 0,
            "checklists_unmapped" => 4567,
            "unresolved_taxa" => Enum.map(1..1234, &"Taxon #{&1}")
          },
          :completed_with_errors
        )
        |> ImportComponents.import_details()

      assert details =~ "4,567 checklists not imported"
      assert details =~ "1,234 taxa unrecognized"
    end

    test "a failed run reports its error instead of counts" do
      details =
        ImportComponents.import_details(%ImportLog{
          status: :failed,
          error: "The export contained no CSV file."
        })

      assert details == "The export contained no CSV file."
    end
  end

  describe "import_status/1 timestamps" do
    defp status_html(assigns) do
      render_component(&ImportComponents.import_status/1, assigns)
    end

    test "a finished run shows its finish time, relative and never as bare UTC" do
      html =
        status_html(%{
          id: "s",
          last_run: %ImportLog{
            status: :completed,
            summary: %{"checklists_created" => 1, "observations_created" => 1},
            started_at: minutes_ago(6),
            finished_at: minutes_ago(3)
          }
        })

      assert html =~ "Finished"
      assert html =~ "3 minutes ago"
      # The UTC stamp is only ever in the hover title, never the visible text.
      refute visible_text(html) =~ "UTC"
    end

    test "a run in progress shows its start time, relative" do
      html =
        status_html(%{
          id: "s",
          running: "eBird import in progress...",
          last_run: %ImportLog{status: :running, started_at: minutes_ago(2)}
        })

      assert html =~ "Started"
      assert html =~ "2 minutes ago"
      refute html =~ "Finished"
    end

    test "does not show a stale start time when the running log is a previous finished run" do
      html =
        status_html(%{
          id: "s",
          running: "eBird import in progress...",
          last_run: %ImportLog{status: :completed, started_at: minutes_ago(2)}
        })

      refute html =~ "Started"
    end

    test "a run finished with issues reassures that skipped items are kept" do
      html =
        status_html(%{
          id: "s",
          last_run: %ImportLog{
            status: :completed_with_errors,
            summary: %{"checklists_unmapped" => 2},
            finished_at: minutes_ago(3)
          }
        })

      assert html =~ "have been saved and may be imported later"
    end

    test "a clean run carries no such reassurance" do
      html =
        status_html(%{
          id: "s",
          last_run: %ImportLog{
            status: :completed,
            summary: %{"checklists_created" => 1, "observations_created" => 1},
            finished_at: minutes_ago(3)
          }
        })

      refute html =~ "have been saved and may be imported later"
    end

    defp minutes_ago(n), do: DateTime.add(DateTime.utc_now(), -n, :minute)

    defp visible_text(html) do
      Regex.replace(~r/<[^>]*>/, html, " ")
    end
  end
end
