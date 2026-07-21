defmodule Kjogvi.Imports.UploadTest do
  # Not async: swaps the Kjogvi.Imports.Upload application env.
  use ExUnit.Case, async: false

  alias Kjogvi.Imports.Upload

  setup do
    dir = Path.join(System.tmp_dir!(), "imports_#{System.unique_integer([:positive])}")
    original = Application.get_env(:kjogvi, Upload)

    Application.put_env(:kjogvi, Upload,
      adapter: Kjogvi.Imports.Upload.LocalAdapter,
      path: dir
    )

    on_exit(fn ->
      Application.put_env(:kjogvi, Upload, original)
      File.rm_rf(dir)
    end)

    %{dir: dir, user: %{id: 42}}
  end

  describe "configured?/0" do
    test "true when the local adapter has a path" do
      assert Upload.configured?()
    end

    test "false when the local adapter has no path" do
      Application.put_env(:kjogvi, Upload, adapter: Kjogvi.Imports.Upload.LocalAdapter)

      refute Upload.configured?()
    end

    test "false when the S3 adapter has no bucket" do
      Application.put_env(:kjogvi, Upload,
        adapter: Kjogvi.Imports.Upload.S3Adapter,
        bucket: nil
      )

      refute Upload.configured?()
    end
  end

  test "store/4 scopes the key under kind and user id", %{user: user} do
    assert {:ok, key} = Upload.store(user, :ebird, "zip", "payload")
    assert key =~ ~r{^imports/ebird/42/[0-9a-f-]+\.zip$}
  end

  test "store/4 then fetch_to/2 round-trips the content", %{dir: dir, user: user} do
    assert {:ok, key} = Upload.store(user, :ebird, "zip", "payload")

    local = Path.join(dir, "fetched.zip")
    assert :ok = Upload.fetch_to(key, local)
    assert File.read!(local) == "payload"
  end

  test "delete/1 removes a stored upload", %{dir: dir, user: user} do
    {:ok, key} = Upload.store(user, :ebird, "zip", "payload")
    assert File.exists?(Path.join(dir, key))

    assert :ok = Upload.delete(key)
    refute File.exists?(Path.join(dir, key))
  end

  test "delete/1 succeeds when the upload is already gone" do
    assert :ok = Upload.delete("imports/ebird/42/missing.zip")
  end
end
