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

  describe "configured?/0" do
    test "true when the local adapter has a path" do
      assert Datasets.configured?()
    end

    test "false when the local adapter has no path" do
      Application.put_env(:kjogvi, Kjogvi.Datasets, adapter: Kjogvi.Datasets.LocalAdapter)

      refute Datasets.configured?()
    end

    test "false when the S3 adapter has no bucket" do
      Application.put_env(:kjogvi, Kjogvi.Datasets,
        adapter: Kjogvi.Datasets.S3Adapter,
        bucket: nil
      )

      refute Datasets.configured?()
    end

    test "true when the S3 adapter has a bucket" do
      Application.put_env(:kjogvi, Kjogvi.Datasets,
        adapter: Kjogvi.Datasets.S3Adapter,
        bucket: "snapshots"
      )

      assert Datasets.configured?()
    end
  end

  test "write/read round-trips a snapshot under a nested key", %{dir: dir} do
    assert :ok = Datasets.write("geo/test.csv", "a,b\n1,2\n")

    assert File.exists?(Path.join(dir, "geo/test.csv"))
    assert {:ok, "a,b\n1,2\n"} = Datasets.read("geo/test.csv")
  end

  test "with :otp_app, resolves :path under the app's priv, independent of cwd" do
    rel = "datasets_test_#{System.unique_integer([:positive])}"
    abs = Application.app_dir(:kjogvi, Path.join("priv", rel))
    on_exit(fn -> File.rm_rf(abs) end)

    Application.put_env(:kjogvi, Kjogvi.Datasets,
      adapter: Kjogvi.Datasets.LocalAdapter,
      otp_app: :kjogvi,
      path: Path.join("priv", rel)
    )

    assert :ok = Datasets.write("geo/test.csv", "content")
    # Written under the app's priv (absolute), not the cwd-relative "priv/...".
    assert File.exists?(Path.join(abs, "geo/test.csv"))
    assert {:ok, "content"} = Datasets.read("geo/test.csv")
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

  describe "snapshot_status/1" do
    defmodule RaisingAdapter do
      @behaviour Kjogvi.Datasets.Adapter

      def configured?(_config), do: true
      def write(_config, _key, _content), do: raise("storage down")
      def read(_config, _key), do: raise("storage down")
      def last_modified(_config, _key), do: raise("storage down")
    end

    test "returns the modification time for an existing snapshot" do
      assert :ok = Datasets.write("geo/test.csv", "content")

      assert {:ok, %DateTime{}} = Datasets.snapshot_status("geo/test.csv")
    end

    test "returns none for a missing snapshot" do
      assert Datasets.snapshot_status("geo/missing.csv") == :none
    end

    test "returns not_configured when the adapter is unconfigured" do
      Application.put_env(:kjogvi, Kjogvi.Datasets, adapter: Kjogvi.Datasets.S3Adapter)

      assert Datasets.snapshot_status("geo/test.csv") == :not_configured
    end

    test "returns an error instead of raising when the storage check blows up" do
      Application.put_env(:kjogvi, Kjogvi.Datasets, adapter: RaisingAdapter)

      assert {:error, %RuntimeError{}} = Datasets.snapshot_status("geo/test.csv")
    end
  end
end
