defmodule Kjogvi.Store.ChecklistPreloadTest do
  # The store is the app's named singleton. Tests stay isolated by keying each
  # one to a unique synthetic user id, so they can run async without clobbering
  # each other's state.
  use ExUnit.Case, async: true

  alias Kjogvi.Store.ChecklistPreload

  setup do
    %{user: %{id: System.unique_integer([:positive])}}
  end

  test "an untouched user has no preloads", %{user: user} do
    preloads = ChecklistPreload.get_preloads(user)

    assert preloads.checklists == []
    assert preloads.last_preload_time == nil
  end

  test "stored checklists are returned with a preload timestamp", %{user: user} do
    checklists = [%{ebird_id: "S1"}, %{ebird_id: "S2"}]

    :ok = ChecklistPreload.store_checklists(user, checklists)
    preloads = ChecklistPreload.get_preloads(user)

    assert preloads.checklists == checklists
    assert %DateTime{} = preloads.last_preload_time
  end

  test "storing an empty list still stamps a preload time", %{user: user} do
    :ok = ChecklistPreload.store_checklists(user, [])
    preloads = ChecklistPreload.get_preloads(user)

    assert preloads.checklists == []
    assert %DateTime{} = preloads.last_preload_time
  end

  test "reset clears previously stored checklists", %{user: user} do
    :ok = ChecklistPreload.store_checklists(user, [%{ebird_id: "S1"}])
    :ok = ChecklistPreload.reset_preloads(user)
    preloads = ChecklistPreload.get_preloads(user)

    assert preloads.checklists == []
    assert preloads.last_preload_time == nil
  end

  test "preloads are isolated per user" do
    user_a = %{id: System.unique_integer([:positive])}
    user_b = %{id: System.unique_integer([:positive])}

    :ok = ChecklistPreload.store_checklists(user_a, [%{ebird_id: "A1"}])

    assert ChecklistPreload.get_preloads(user_a).checklists == [%{ebird_id: "A1"}]
    assert ChecklistPreload.get_preloads(user_b).checklists == []
  end
end
