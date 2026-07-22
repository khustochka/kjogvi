defmodule KjogviWeb.Admin.ImportUploadControllerTest do
  # Not async: swaps the Kjogvi.Imports.Upload application env.
  use KjogviWeb.ConnCase, async: false

  import Kjogvi.AccountsFixtures

  alias Kjogvi.Imports
  alias Kjogvi.Imports.Upload

  setup do
    dir = Path.join(System.tmp_dir!(), "upload_download_#{System.unique_integer([:positive])}")
    original = Application.get_env(:kjogvi, Upload)

    Application.put_env(:kjogvi, Upload,
      adapter: Kjogvi.Imports.Upload.LocalAdapter,
      path: dir
    )

    on_exit(fn ->
      Application.put_env(:kjogvi, Upload, original)
      File.rm_rf(dir)
    end)

    user = user_fixture()
    {:ok, key} = Upload.store(user, :ebird, "zip", "zip bytes")
    {:ok, log} = Imports.enqueue_ebird_import(user, key)

    %{log: log}
  end

  test "returns 404 for a non-admin user", %{conn: conn, log: log} do
    conn = conn |> login_user(user_fixture()) |> get(~p"/admin/import_logs/#{log}/upload")

    assert response(conn, 404)
  end

  test "downloads the stored upload", %{conn: conn, log: log} do
    conn = conn |> login_user(admin_fixture()) |> get(~p"/admin/import_logs/#{log}/upload")

    assert response(conn, 200) == "zip bytes"

    assert get_resp_header(conn, "content-disposition") ==
             [~s(attachment; filename="import-#{log.id}-upload.zip")]
  end

  test "returns 404 once the upload is consumed", %{conn: conn, log: log} do
    :ok = Imports.clear_upload_key(log.id)

    conn = conn |> login_user(admin_fixture()) |> get(~p"/admin/import_logs/#{log}/upload")

    assert response(conn, 404) =~ "consumed"
  end

  test "returns 404 when the file is missing from storage", %{conn: conn, log: log} do
    File.rm_rf!(Application.get_env(:kjogvi, Upload)[:path])

    conn = conn |> login_user(admin_fixture()) |> get(~p"/admin/import_logs/#{log}/upload")

    assert response(conn, 404) =~ "could not be read"
  end
end
