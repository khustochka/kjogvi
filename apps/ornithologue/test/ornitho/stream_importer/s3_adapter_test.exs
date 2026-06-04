defmodule Ornitho.StreamImporter.S3AdapterTest do
  use ExUnit.Case, async: false

  alias Ornitho.StreamImporter.S3Adapter

  setup do
    previous = Application.get_env(:ornithologue, Ornitho.StreamImporter)
    on_exit(fn -> Application.put_env(:ornithologue, Ornitho.StreamImporter, previous) end)
  end

  defp put_config(opts) do
    Application.put_env(:ornithologue, Ornitho.StreamImporter, opts)
  end

  describe "validate_config/0" do
    test "requires bucket and region" do
      put_config(adapter: S3Adapter)
      assert {:error, message} = S3Adapter.validate_config()
      assert message =~ "bucket is not configured"
      assert message =~ "region is not configured"
    end

    test "succeeds with only the required keys" do
      put_config(adapter: S3Adapter, bucket: "books", region: "us-east-1")
      assert {:ok, config} = S3Adapter.validate_config()
      assert config == %{bucket: "books", region: "us-east-1"}
    end

    test "carries optional credentials through when present" do
      put_config(
        adapter: S3Adapter,
        bucket: "books",
        region: "us-east-1",
        access_key_id: "AKIA",
        secret_access_key: "secret"
      )

      assert {:ok, config} = S3Adapter.validate_config()
      assert config[:access_key_id] == "AKIA"
      assert config[:secret_access_key] == "secret"
    end

    test "omits blank optional credentials" do
      put_config(
        adapter: S3Adapter,
        bucket: "books",
        region: "us-east-1",
        access_key_id: "",
        secret_access_key: nil
      )

      assert {:ok, config} = S3Adapter.validate_config()
      refute Map.has_key?(config, :access_key_id)
      refute Map.has_key?(config, :secret_access_key)
    end
  end

  describe "request_overrides/1" do
    test "always passes region" do
      assert S3Adapter.request_overrides(%{region: "eu-central-1"})[:region] == "eu-central-1"
    end

    test "includes credentials when set" do
      overrides =
        S3Adapter.request_overrides(%{
          region: "eu-central-1",
          access_key_id: "AKIA",
          secret_access_key: "secret"
        })

      assert overrides[:access_key_id] == "AKIA"
      assert overrides[:secret_access_key] == "secret"
    end

    test "omits credentials when absent or blank, falling back to the global chain" do
      overrides =
        S3Adapter.request_overrides(%{
          region: "eu-central-1",
          access_key_id: "",
          secret_access_key: nil
        })

      assert Keyword.keys(overrides) == [:region]
    end
  end
end
