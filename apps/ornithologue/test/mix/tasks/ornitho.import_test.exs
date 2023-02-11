defmodule Mix.Tasks.Ornitho.ImportTest do
  use ExUnit.Case
  use Ornitho.RepoCase, async: true

  alias Ornitho.Importer

  test "when non-existent module is given it fails" do
    assert_raise Mix.Error,
                 "Could not load Importer module Ornitho.Importer.Fake.V2, error: :nofile.",
                 fn ->
                   Mix.Task.rerun("ornitho.import", [Importer.Fake.V2])
                 end
  end

  test "when module without `process_import` is given it fails" do
    assert_raise Mix.Error,
                 "Module Mix.Tasks.Ornitho.ImportTest is not an Importer, " <>
                   "needs to define function 'process_import/1'.",
                 fn ->
                   Mix.Task.rerun("ornitho.import", [Mix.Tasks.Ornitho.ImportTest])
                 end
  end

  test "passes with correct importer" do
    Mix.Task.rerun("ornitho.import", [Importer.Demo.V1])
  end
end
