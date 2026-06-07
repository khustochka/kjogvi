defmodule Kjogvi.Util.PresenceTest do
  use ExUnit.Case, async: true

  alias Kjogvi.Util.Presence

  doctest Kjogvi.Util.Presence

  describe "presence/1" do
    test "returns nil for nil" do
      assert Presence.presence(nil) == nil
    end

    test "returns nil for an empty string" do
      assert Presence.presence("") == nil
    end

    test "returns nil for a whitespace-only string" do
      assert Presence.presence("   ") == nil
    end

    test "returns the trimmed string for a present string" do
      assert Presence.presence("Anna") == "Anna"
      assert Presence.presence("  Anna  ") == "Anna"
    end

    test "returns non-binary values unchanged" do
      assert Presence.presence(0) == 0
      assert Presence.presence(false) == false
    end
  end
end
