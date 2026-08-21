defmodule Kjogvi.Util.TimeTest do
  use ExUnit.Case, async: true

  doctest Kjogvi.Util.Time

  alias Kjogvi.Util.Time

  describe "relative/2" do
    test "singular units drop the plural s" do
      now = ~U[2026-08-21 14:05:00Z]
      assert Time.relative(~U[2026-08-21 14:04:00Z], now) == "1 minute ago"
      assert Time.relative(~U[2026-08-21 13:05:00Z], now) == "1 hour ago"
      assert Time.relative(~U[2026-08-20 14:05:00Z], now) == "1 day ago"
    end

    test "a future time reads just now" do
      now = ~U[2026-08-21 14:05:00Z]
      assert Time.relative(~U[2026-08-21 14:06:00Z], now) == "just now"
    end
  end
end
