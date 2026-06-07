defmodule Kjogvi.Types.ImportSourceTest do
  use ExUnit.Case, async: true

  alias Kjogvi.Types.ImportSource

  describe "values/0" do
    test "returns the supported import sources" do
      assert ImportSource.values() == [:ebird, :legacy]
    end
  end
end
