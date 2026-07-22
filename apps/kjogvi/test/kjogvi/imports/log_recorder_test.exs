defmodule Kjogvi.Imports.LogRecorderTest do
  use Kjogvi.DataCase, async: false

  @moduletag :capture_log

  alias Kjogvi.Imports.ImportLog
  alias Kjogvi.Repo
  alias Kjogvi.TestJobs.LoggedWorker

  setup do
    user = Kjogvi.AccountsFixtures.user_fixture()

    {:ok, log} =
      %{source: :ebird, user_id: user.id}
      |> ImportLog.create_changeset()
      |> Repo.insert()

    %{log: log}
  end

  defp drain(args) do
    Oban.insert!(LoggedWorker.new(args))
    Oban.drain_queue(queue: :imports)
  end

  defp reload(log), do: Repo.get!(ImportLog, log.id)

  test "a successful run is recorded as completed with its summary", %{log: log} do
    summary = %{"checklists_created" => 2}
    drain(%{import_log_id: log.id, summary: summary})

    log = reload(log)
    assert log.status == :completed
    assert log.summary == summary
    assert log.started_at
    assert log.finished_at
  end

  test "the worker's completion_status/1 can report completed_with_errors", %{log: log} do
    drain(%{import_log_id: log.id, summary: %{"errors" => true}})

    assert reload(log).status == :completed_with_errors
  end

  test "an error return is recorded as failed with the reason", %{log: log} do
    drain(%{import_log_id: log.id, error: "bad input"})

    log = reload(log)
    assert log.status == :failed
    assert log.error == "bad input"
  end

  test "a raise is recorded as failed with the exception message", %{log: log} do
    drain(%{import_log_id: log.id, raise: true})

    log = reload(log)
    assert log.status == :failed
    assert log.error == "logged boom"
  end

  test "a cancelled run is recorded as failed", %{log: log} do
    drain(%{import_log_id: log.id, cancel: "not worth retrying"})

    log = reload(log)
    assert log.status == :failed
    assert log.error == "not worth retrying"
  end

  test "a job without an import_log_id leaves logs untouched", %{log: log} do
    drain(%{})

    assert reload(log).status == :queued
  end

  test "a job whose log is gone still completes without crashing", %{log: log} do
    Repo.delete!(log)

    assert %{success: 1} = drain(%{import_log_id: log.id})
  end
end
