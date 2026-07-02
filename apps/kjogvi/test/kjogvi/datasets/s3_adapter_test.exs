defmodule Kjogvi.Datasets.S3AdapterTest do
  use ExUnit.Case, async: true

  alias Kjogvi.Datasets.S3Adapter

  describe "parse_http_date/1" do
    test "parses an RFC 7231 Last-Modified value" do
      assert {:ok, ~U[2009-10-12 17:50:00Z]} =
               S3Adapter.parse_http_date("Mon, 12 Oct 2009 17:50:00 GMT")
    end

    test "rejects malformed values" do
      assert {:error, {:invalid_http_date, _}} = S3Adapter.parse_http_date("not a date")

      assert {:error, {:invalid_http_date, _}} =
               S3Adapter.parse_http_date("Mon, 12 Okt 2009 17:50:00 GMT")

      assert {:error, {:invalid_http_date, _}} =
               S3Adapter.parse_http_date("Mon, 12 Oct 2009 17:50:00 CET")
    end
  end
end
