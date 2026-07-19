defmodule Kjogvi.Jobs.BootstrapTest do
  # Not async: swaps the global Kjogvi.Datasets and Kjogvi.Settings config.
  use Kjogvi.DataCase, async: false

  @moduletag :capture_log

  alias Kjogvi.Jobs.Bootstrap

  # An empty snapshot dir makes both restores fail with :enoent, and the offline
  # demo importer stands in for the configured taxonomy default.
  setup do
    dir = Path.join(System.tmp_dir!(), "datasets_#{System.unique_integer([:positive])}")
    original_datasets = Application.get_env(:kjogvi, Kjogvi.Datasets)
    original_settings = Application.get_env(:kjogvi, Kjogvi.Settings, [])

    Application.put_env(:kjogvi, Kjogvi.Datasets,
      adapter: Kjogvi.Datasets.LocalAdapter,
      path: dir
    )

    Application.put_env(
      :kjogvi,
      Kjogvi.Settings,
      Keyword.put(original_settings, :default_taxonomy_importer, Ornitho.Importer.Demo.V1)
    )

    on_exit(fn ->
      Application.put_env(:kjogvi, Kjogvi.Datasets, original_datasets)
      Application.put_env(:kjogvi, Kjogvi.Settings, original_settings)
      File.rm_rf(dir)
    end)

    :ok
  end

  test "holds a single exclusive slot" do
    job1 = Oban.insert!(Bootstrap.new(%{}))
    job2 = Oban.insert!(Bootstrap.new(%{}))

    assert job2.conflict?
    assert job2.id == job1.id
  end

  test "imports the taxonomy before failing on the missing location snapshot" do
    assert {:error, {:common_locations, :enoent}} = perform_job(Bootstrap, %{})

    assert Ornitho.Finder.Book.exists?("demo", "v1")
  end

  test "skips a taxonomy that is already imported" do
    {:ok, _count} = Ornitho.Importer.Demo.V1.process_import()

    # Re-running would raise if the step did not skip the existing book.
    assert {:error, {:common_locations, :enoent}} = perform_job(Bootstrap, %{})
  end
end
