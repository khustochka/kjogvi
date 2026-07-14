defmodule Kjogvi.Geo.Import.GuardTest do
  use ExUnit.Case, async: true

  alias Kjogvi.Geo.Import.Guard

  describe "state/2" do
    test "blocks once the dataset has rows, regardless of snapshot" do
      assert Guard.state(true, :none) == :blocked
      assert Guard.state(true, :not_configured) == :blocked
      assert Guard.state(true, {:ok, DateTime.utc_now()}) == :blocked
      assert Guard.state(true, {:error, :enoent}) == :blocked
    end

    test "confirms when empty but a snapshot exists" do
      assert Guard.state(false, {:ok, DateTime.utc_now()}) == :confirm
    end

    test "confirms when empty and the storage check failed (a snapshot may exist)" do
      assert Guard.state(false, {:error, :timeout}) == :confirm
    end

    test "runs freely when empty with no snapshot or no storage" do
      assert Guard.state(false, :none) == :free
      assert Guard.state(false, :not_configured) == :free
    end
  end
end
