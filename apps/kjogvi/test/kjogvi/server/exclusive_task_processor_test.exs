defmodule Kjogvi.Server.ExclusiveTaskProcessorTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Kjogvi.Server.ExclusiveTaskProcessor, as: Processor
  alias Kjogvi.Util.AsyncResult
  alias Kjogvi.Util.PubSubTopic

  setup do
    # Each test drives its own isolated instance (addressed by pid) so statuses
    # from one test can't leak into another (the app also runs a singleton).
    server = start_supervised!({Processor, name: nil})
    %{server: server}
  end

  # Parks the task until the test releases it, so we can observe the loading
  # state and the one-task-per-key guard deterministically. The task hands back
  # `result` once released.
  defp blocking_task(test_pid, result) do
    fn _key ->
      send(test_pid, {:task_started, self()})

      receive do
        :release -> result
      end
    end
  end

  defp release(task_pid), do: send(task_pid, :release)

  # Terminal results arrive asynchronously via the task message, so poll the
  # public API until the status satisfies `fun` (or give up and flunk).
  defp await_status(server, key, fun, attempts \\ 100) do
    status = Processor.get_status(key, server: server)

    cond do
      fun.(status) ->
        status

      attempts == 0 ->
        flunk("status for #{inspect(key)} never satisfied predicate: #{inspect(status)}")

      true ->
        Process.sleep(5)
        await_status(server, key, fun, attempts - 1)
    end
  end

  describe "get_status/2" do
    test "returns a blank AsyncResult for an unknown key", %{server: server} do
      assert Processor.get_status({:nope, 1}, server: server) == %AsyncResult{}
    end
  end

  describe "start_task/3" do
    test "tracks loading, then the successful result", %{server: server} do
      key = {:job, 1}

      Processor.start_task(key, fn _key -> {:ok, :done} end, server: server)

      status = await_status(server, key, & &1.ok?)
      assert status.result == :done
      refute status.loading
      refute status.failed
    end

    test "uses the message option as the loading state", %{server: server} do
      key = {:job, 1}

      Processor.start_task(key, blocking_task(self(), {:ok, :ok}),
        server: server,
        message: "warming up"
      )

      assert_receive {:task_started, _pid}
      assert Processor.get_status(key, server: server).loading == %{message: "warming up"}
    end

    test "records a failure for an {:error, _} result", %{server: server} do
      key = {:job, 1}

      Processor.start_task(key, fn _key -> {:error, :nope} end, server: server)

      status = await_status(server, key, &(&1.failed != nil))
      assert status.failed == :nope
      refute status.loading
    end

    test "records a failure when the task returns a malformed result", %{server: server} do
      key = {:job, 1}

      log =
        capture_log(fn ->
          Processor.start_task(key, fn _key -> :not_a_tuple end, server: server)
          assert await_status(server, key, &(&1.failed != nil)).failed == :malformed_result
        end)

      assert log =~ "malformed"
    end

    test "records a failure when the task crashes", %{server: server} do
      key = {:job, 1}

      capture_log(fn ->
        Processor.start_task(key, fn _key -> raise "boom" end, server: server)
        status = await_status(server, key, &(&1.failed != nil))
        assert {%RuntimeError{message: "boom"}, _stacktrace} = status.failed
      end)
    end

    test "is a no-op while a task for the same key is loading", %{server: server} do
      key = {:job, 1}

      Processor.start_task(key, blocking_task(self(), {:ok, :first}), server: server)
      assert_receive {:task_started, first_pid}

      # A second request for the same key while the first is in flight must not
      # spawn another task.
      Processor.start_task(key, blocking_task(self(), {:ok, :second}), server: server)
      refute_receive {:task_started, _pid}, 50

      release(first_pid)
      assert await_status(server, key, & &1.ok?).result == :first
    end

    test "tasks under different keys run concurrently", %{server: server} do
      Processor.start_task({:job, 1}, blocking_task(self(), {:ok, :one}), server: server)
      Processor.start_task({:job, 2}, blocking_task(self(), {:ok, :two}), server: server)

      assert_receive {:task_started, pid_a}
      assert_receive {:task_started, pid_b}
      assert pid_a != pid_b

      release(pid_a)
      release(pid_b)

      assert await_status(server, {:job, 1}, & &1.ok?).result == :one
      assert await_status(server, {:job, 2}, & &1.ok?).result == :two
    end

    test "a finished status is retained and a later start_task runs fresh", %{server: server} do
      key = {:job, 1}

      Processor.start_task(key, fn _key -> {:ok, :first} end, server: server)
      assert await_status(server, key, & &1.ok?).result == :first

      Processor.start_task(key, fn _key -> {:ok, :second} end, server: server)
      assert await_status(server, key, &(&1.ok? and &1.result == :second)).result == :second
    end
  end

  describe "progress updates over PubSub" do
    test "merges a broadcast progress status into the tracked status", %{server: server} do
      key = {:job, 1}

      Processor.start_task(key, blocking_task(self(), {:ok, :done}), server: server)
      assert_receive {:task_started, task_pid}

      Phoenix.PubSub.broadcast(
        Kjogvi.PubSub,
        PubSubTopic.for_key(key),
        {:progress, key, %{message: "halfway"}}
      )

      assert await_status(server, key, &(&1.loading == %{message: "halfway"}))

      release(task_pid)
      assert await_status(server, key, & &1.ok?).result == :done
    end

    test "ignores progress for a key that is not being tracked", %{server: server} do
      key = {:untracked, 1}

      send(server, {:progress, key, %{message: "ghost"}})

      assert Processor.get_status(key, server: server) == %AsyncResult{}
    end
  end

  describe "lifecycle events" do
    # A subscriber to the key topic learns about start/completion without polling.
    # The processor broadcasts the AsyncResult exactly as stored, so the event
    # payload matches what get_status/2 would return.
    setup %{server: server} do
      key = {:job, 1}
      Phoenix.PubSub.subscribe(Kjogvi.PubSub, PubSubTopic.for_key(key))
      %{server: server, key: key}
    end

    test "broadcasts :start with the loading status", %{server: server, key: key} do
      Processor.start_task(key, blocking_task(self(), {:ok, :done}),
        server: server,
        message: "warming up"
      )

      assert_receive {:lifecycle, :start, ^key, %AsyncResult{loading: %{message: "warming up"}}}
    end

    test "broadcasts :ok with the successful result", %{server: server, key: key} do
      Processor.start_task(key, fn _key -> {:ok, :done} end, server: server)

      assert_receive {:lifecycle, :ok, ^key, %AsyncResult{ok?: true, result: :done}}
    end

    test "broadcasts :error for an {:error, _} result", %{server: server, key: key} do
      Processor.start_task(key, fn _key -> {:error, :nope} end, server: server)

      assert_receive {:lifecycle, :error, ^key, %AsyncResult{failed: :nope}}
    end

    test "broadcasts :error when the task crashes", %{server: server, key: key} do
      capture_log(fn ->
        Processor.start_task(key, fn _key -> raise "boom" end, server: server)

        assert_receive {:lifecycle, :error, ^key, %AsyncResult{failed: failed}}
        assert {%RuntimeError{message: "boom"}, _stacktrace} = failed
      end)
    end

    test "does not broadcast a second :start while a task is loading", %{server: server, key: key} do
      Processor.start_task(key, blocking_task(self(), {:ok, :first}), server: server)
      assert_receive {:lifecycle, :start, ^key, _}
      assert_receive {:task_started, first_pid}

      Processor.start_task(key, blocking_task(self(), {:ok, :second}), server: server)
      refute_receive {:lifecycle, :start, ^key, _}, 50

      release(first_pid)
    end
  end
end
