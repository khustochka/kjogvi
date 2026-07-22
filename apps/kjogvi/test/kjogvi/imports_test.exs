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
      assert log.upload_key == "some/key.zip"

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

  describe "list_import_logs_for_admin/2" do
    test "lists all users' runs newest first with users preloaded", %{user: user} do
      other_user = Kjogvi.AccountsFixtures.user_fixture()

      {:ok, older} = Imports.enqueue_ebird_import(user, "a.zip")
      {:ok, newer} = Imports.enqueue_ebird_import(other_user, "b.zip")

      page = Imports.list_import_logs_for_admin()

      assert Enum.map(page.entries, & &1.id) == [newer.id, older.id]
      assert Enum.map(page.entries, & &1.user.id) == [other_user.id, user.id]
    end

    test ":issues narrows to failed and completed-with-errors runs", %{user: user} do
      users = [user | Enum.map(1..3, fn _ -> Kjogvi.AccountsFixtures.user_fixture() end)]

      [queued, completed, with_errors, failed] =
        Enum.map(users, fn u ->
          {:ok, log} = Imports.enqueue_ebird_import(u, "a.zip")
          log
        end)

      :ok = Imports.log_completed(completed.id, :completed, %{})
      :ok = Imports.log_completed(with_errors.id, :completed_with_errors, %{})
      :ok = Imports.log_failed(failed.id, "boom")

      page = Imports.list_import_logs_for_admin(:issues)

      assert Enum.map(page.entries, & &1.id) == [failed.id, with_errors.id]
      refute queued.id in Enum.map(page.entries, & &1.id)
    end

    test "paginates", %{user: user} do
      other_user = Kjogvi.AccountsFixtures.user_fixture()

      {:ok, older} = Imports.enqueue_ebird_import(user, "a.zip")
      {:ok, newer} = Imports.enqueue_ebird_import(other_user, "b.zip")

      page = Imports.list_import_logs_for_admin(:all, %{page: 2, page_size: 1})

      assert Enum.map(page.entries, & &1.id) == [older.id]
      assert page.total_entries == 2
      refute newer.id in Enum.map(page.entries, & &1.id)
    end
  end

  describe "get_import_log!/1" do
    test "returns the run with its user preloaded", %{user: user} do
      {:ok, log} = Imports.enqueue_ebird_import(user, "a.zip")

      assert Imports.get_import_log!(log.id).user.id == user.id
    end

    test "raises on an unknown id" do
      assert_raise Ecto.NoResultsError, fn -> Imports.get_import_log!(0) end
    end
  end

  describe "paginate_import_errors/2" do
    test "pages the run's errors oldest first", %{user: user} do
      {:ok, log} = Imports.enqueue_ebird_import(user, "a.zip")

      :ok =
        Imports.record_errors(log.id, [
          %{category: :invalid, rows: []},
          %{category: :unmapped, submission_id: "S1", rows: []}
        ])

      page = Imports.paginate_import_errors(log.id, %{page: 1, page_size: 1})

      assert [%{category: :invalid}] = page.entries
      assert page.total_entries == 2

      assert [%{category: :unmapped}] =
               Imports.paginate_import_errors(log.id, %{page: 2, page_size: 1}).entries
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

  describe "error records" do
    setup %{user: user} do
      {:ok, log} = Imports.enqueue_ebird_import(user, "a.zip")
      %{log: log}
    end

    test "record_errors/2 persists entries readable in order", %{log: log} do
      entries = [
        %{category: :unmapped, submission_id: "S1", rows: [%{"Location ID" => "L1"}]},
        %{category: :failed, submission_id: "S2", rows: [%{"Location ID" => "L2"}], error: "bad"}
      ]

      assert :ok = Imports.record_errors(log.id, entries)

      assert [first, second] = Imports.list_import_errors(log.id)

      assert first.category == :unmapped
      assert first.submission_id == "S1"
      assert first.rows == [%{"Location ID" => "L1"}]
      assert first.error == nil

      assert second.category == :failed
      assert second.error == "bad"
    end

    test "record_errors/2 with no entries writes nothing", %{log: log} do
      assert :ok = Imports.record_errors(log.id, [])
      assert Imports.list_import_errors(log.id) == []
    end

    test "deleting the log deletes its error records", %{log: log} do
      :ok = Imports.record_errors(log.id, [%{category: :invalid, rows: []}])

      Kjogvi.Repo.delete!(log)

      assert Kjogvi.Repo.aggregate(Kjogvi.Imports.ImportError, :count) == 0
    end
  end

  describe "clear_upload_key/1" do
    test "unlinks the upload from the log", %{user: user} do
      {:ok, log} = Imports.enqueue_ebird_import(user, "a.zip")

      assert :ok = Imports.clear_upload_key(log.id)
      assert Kjogvi.Repo.get!(ImportLog, log.id).upload_key == nil
    end

    test "is a no-op without a log id" do
      assert :ok = Imports.clear_upload_key(nil)
    end
  end
end
