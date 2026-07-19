defmodule Kjogvi.SettingsTest do
  use ExUnit.Case, async: true

  alias Kjogvi.Settings

  describe "default_taxonomy/0" do
    test "derives the signature from the configured default importer" do
      assert Settings.default_taxonomy() == "ebird/v2025"
    end
  end
end
