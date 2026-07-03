defmodule Kjogvi.DatasetsTest do
  # Not async: swaps the Kjogvi.Datasets application env.
  use ExUnit.Case, async: false

  alias Kjogvi.Datasets

  setup do
    dir = Path.join(System.tmp_dir!(), "datasets_#{System.unique_integer([:positive])}")
    original = Application.get_env(:kjogvi, Kjogvi.Datasets)

    Application.put_env(:kjogvi, Kjogvi.Datasets,
      adapter: Kjogvi.Datasets.LocalAdapter,
      path: dir
    )

    on_exit(fn ->
      Application.put_env(:kjogvi, Kjogvi.Datasets, original)
      File.rm_rf(dir)
    end)

    %{dir: dir}
  end

  test "write/read round-trips a snapshot under a nested key", %{dir: dir} do
    assert :ok = Datasets.write("geo/test.csv", "a,b\n1,2\n")

    assert File.exists?(Path.join(dir, "geo/test.csv"))
    assert {:ok, "a,b\n1,2\n"} = Datasets.read("geo/test.csv")
  end

  test "read returns enoent for a missing snapshot" do
    assert {:error, :enoent} = Datasets.read("geo/missing.csv")
  end

  describe "last_modified/1" do
    test "returns the write time as a UTC datetime" do
      before_write = DateTime.utc_now(:second)
      assert :ok = Datasets.write("geo/test.csv", "content")

      assert {:ok, %DateTime{time_zone: "Etc/UTC"} = modified_at} =
               Datasets.last_modified("geo/test.csv")

      # File mtimes have second granularity; allow for the truncation.
      assert DateTime.diff(modified_at, before_write) >= -1
      assert DateTime.diff(DateTime.utc_now(), modified_at) < 60
    end

    test "returns enoent for a missing snapshot" do
      assert {:error, :enoent} = Datasets.last_modified("geo/missing.csv")
    end
  end
end
