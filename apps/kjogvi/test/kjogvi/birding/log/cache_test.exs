defmodule Kjogvi.Birding.Log.CacheTest do
  # Not async: this test flips the global :cache adapter setting and starts
  # a Cachex instance, so it must run in isolation from other suites.
  use ExUnit.Case, async: false

  alias Kjogvi.Birding.Log.Cache

  setup do
    # The default test env runs with the no-op cache adapter, which can't
    # observe hits/misses. Start a real Cachex for the duration of the test
    # and restore the previous setting on exit.
    previous = Application.get_env(:kjogvi, :cache)
    Application.put_env(:kjogvi, :cache, enabled: true)

    {:ok, _pid} = start_supervised({Cachex, name: :kjogvi_cache})

    on_exit(fn -> Application.put_env(:kjogvi, :cache, previous) end)

    :ok
  end

  describe "fetch/2" do
    test "computes and returns the fallback value on a miss" do
      assert Cache.fetch({1, 5, 93}, fn -> :computed end) == :computed
    end

    test "returns the cached value on a hit without re-running the fallback" do
      pid = self()

      Cache.fetch({2, 5, 93}, fn ->
        send(pid, :ran)
        :first
      end)

      assert_received :ran

      result =
        Cache.fetch({2, 5, 93}, fn ->
          send(pid, :ran_again)
          :second
        end)

      assert result == :first
      refute_received :ran_again
    end

    test "different key parts produce independent cache entries" do
      Cache.fetch({3, 5, 93}, fn -> :home end)
      Cache.fetch({3, 366, 366}, fn -> :log_page end)

      assert Cache.fetch({3, 5, 93}, fn -> :recomputed end) == :home
      assert Cache.fetch({3, 366, 366}, fn -> :recomputed end) == :log_page
    end
  end

  describe "invalidate/1" do
    test "evicts every known variant for the given user so the next fetch recomputes" do
      Cache.fetch({4, 5, 93}, fn -> :home end)
      Cache.fetch({4, 366, 366}, fn -> :log_page end)

      :ok = Cache.invalidate(4)

      assert Cache.fetch({4, 5, 93}, fn -> :recomputed end) == :recomputed
      assert Cache.fetch({4, 366, 366}, fn -> :recomputed end) == :recomputed
    end

    test "does not affect cache entries for other users" do
      Cache.fetch({5, 5, 93}, fn -> :user_5 end)
      Cache.fetch({6, 5, 93}, fn -> :user_6 end)

      :ok = Cache.invalidate(5)

      assert Cache.fetch({5, 5, 93}, fn -> :recomputed end) == :recomputed
      assert Cache.fetch({6, 5, 93}, fn -> :user_6 end) == :user_6
    end
  end
end
