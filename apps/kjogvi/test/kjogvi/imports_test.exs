defmodule Kjogvi.ImportsTest do
  use Kjogvi.DataCase, async: true

  alias Kjogvi.Imports
  alias Kjogvi.Imports.ImportLog

  setup do
    %{user: Kjogvi.AccountsFixtures.user_fixture()}
  end

  describe "enqueue_ebird_import/2" do
    test "creates a queued log and the job carrying its id", %{user: user} do
      assert {:ok, %ImportLog{} = log} = Imports.enqueue_ebird_import(user, "some/key.zip")

      assert log.source == :ebird
      assert log.status == :queued
      assert log.user_id == user.id

      log_id = log.id
      user_id = user.id

      assert [
               %Oban.Job{
                 args: %{
                   "import_log_id" => ^log_id,
                   "user_id" => ^user_id,
                   "upload_key" => "some/key.zip"
                 }
               }
             ] = Kjogvi.Repo.all(Oban.Job, prefix: Oban.config().prefix)
    end

    test "a run already in flight rolls the new log back", %{user: user} do
      assert {:ok, _log} = Imports.enqueue_ebird_import(user, "first.zip")
      assert {:error, :already_running} = Imports.enqueue_ebird_import(user, "second.zip")

      assert [%ImportLog{}] = Kjogvi.Repo.all(ImportLog)

      assert [%Oban.Job{args: %{"upload_key" => "first.zip"}}] =
               Kjogvi.Repo.all(Oban.Job, prefix: Oban.config().prefix)
    end
  end

  describe "list_import_logs/1" do
    test "returns only the user's logs, newest first", %{user: user} do
      other_user = Kjogvi.AccountsFixtures.user_fixture()

      {:ok, older} = Imports.enqueue_ebird_import(user, "a.zip")
      {:ok, _other} = Imports.enqueue_ebird_import(other_user, "b.zip")

      # Free the user's exclusive slot so a second run can be enqueued.
      Oban.drain_queue(queue: :imports)
      {:ok, newer} = Imports.enqueue_ebird_import(user, "c.zip")

      assert Enum.map(Imports.list_import_logs(user), & &1.id) == [newer.id, older.id]
    end
  end

  describe "log transitions" do
    setup %{user: user} do
      {:ok, log} = Imports.enqueue_ebird_import(user, "a.zip")
      %{log: log}
    end

    test "log_started/1 marks the run running", %{log: log} do
      assert :ok = Imports.log_started(log.id)

      log = Kjogvi.Repo.get!(ImportLog, log.id)
      assert log.status == :running
      assert log.started_at
      refute log.finished_at
    end

    test "log_completed/3 records the status and summary", %{log: log} do
      summary = %{"checklists_created" => 3}
      assert :ok = Imports.log_completed(log.id, :completed_with_errors, summary)

      log = Kjogvi.Repo.get!(ImportLog, log.id)
      assert log.status == :completed_with_errors
      assert log.summary == summary
      assert log.finished_at
    end

    test "log_failed/2 records the reason", %{log: log} do
      assert :ok = Imports.log_failed(log.id, "it broke")

      log = Kjogvi.Repo.get!(ImportLog, log.id)
      assert log.status == :failed
      assert log.error == "it broke"
      assert log.finished_at
    end

    test "a transition on a deleted log is a no-op", %{log: log} do
      Kjogvi.Repo.delete!(log)

      assert :ok = Imports.log_started(log.id)
    end
  end
end
