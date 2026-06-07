defmodule Kjogvi.Types.ImportSourceTest do
  use ExUnit.Case, async: true

  alias Kjogvi.Types.ImportSource

  describe "values/0" do
    test "returns the supported import sources" do
      assert ImportSource.values() == [:ebird, :legacy]
    end
  end

  describe "label/1" do
    test "returns human-readable labels" do
      assert ImportSource.label(:ebird) == "eBird"
      assert ImportSource.label(:legacy) == "Legacy"
    end
  end
end
