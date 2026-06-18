defmodule Ornitho.UtilTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Ornitho.Util

  describe "cast_string/1" do
    test "trims and returns a non-blank value" do
      assert Util.cast_string("  comcuc  ") == "comcuc"
    end

    test "returns nil for blank or missing values" do
      assert Util.cast_string("") == nil
      assert Util.cast_string("   ") == nil
      assert Util.cast_string(nil) == nil
    end
  end

  describe "cast_integer/1" do
    test "parses an integer" do
      assert Util.cast_integer("42") == 42
      assert Util.cast_integer("  42 ") == 42
    end

    test "returns nil for blank or missing values" do
      assert Util.cast_integer("") == nil
      assert Util.cast_integer(nil) == nil
    end

    test "raises on a non-integer value" do
      assert_raise ArgumentError, fn -> Util.cast_integer("nope") end
    end
  end

  describe "cast_boolean/1" do
    test "parses true and false" do
      assert Util.cast_boolean("true") == true
      assert Util.cast_boolean(" false ") == false
    end

    test "returns nil for blank or missing values" do
      assert Util.cast_boolean("") == nil
      assert Util.cast_boolean(nil) == nil
    end

    test "raises on a value that is not a boolean string" do
      assert_raise ArgumentError, fn -> Util.cast_boolean("yes") end
    end
  end
end
