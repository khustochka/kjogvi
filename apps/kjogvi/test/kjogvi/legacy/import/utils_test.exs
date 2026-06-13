defmodule Kjogvi.Legacy.Import.UtilsTest do
  use ExUnit.Case, async: true

  alias Kjogvi.Legacy.Import.Utils

  describe "convert_timestamp/1" do
    test "returns nil for nil" do
      assert Utils.convert_timestamp(nil) == nil
    end

    test "treats a NaiveDateTime as UTC" do
      naive = ~N[2026-01-02 03:04:05]
      assert Utils.convert_timestamp(naive) == ~U[2026-01-02 03:04:05Z]
    end

    test "parses an ISO 8601 string and pads microseconds to 6 digits" do
      dt = Utils.convert_timestamp("2026-01-02T03:04:05Z")
      assert dt == ~U[2026-01-02 03:04:05.000000Z]
      assert dt.microsecond == {0, 6}
    end
  end

  describe "blank_to_nil/1" do
    test "turns an empty string into nil" do
      assert Utils.blank_to_nil("") == nil
    end

    test "turns a whitespace-only string into nil" do
      assert Utils.blank_to_nil("   \t\n") == nil
    end

    test "trims surrounding whitespace from a non-blank string" do
      assert Utils.blank_to_nil("  hello  ") == "hello"
    end

    test "passes non-binary values through unchanged" do
      assert Utils.blank_to_nil(nil) == nil
      assert Utils.blank_to_nil(42) == 42
    end
  end
end
