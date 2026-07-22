defmodule KjogviWeb.Admin.ImportUploadController do
  @moduledoc """
  Downloads an import run's stored source upload
  (`Kjogvi.Imports.ImportLog.upload_key`) for admin review.
  """

  use KjogviWeb, :controller

  alias Kjogvi.Imports.Upload

  def download(conn, %{"id" => id}) do
    import_log = Kjogvi.Imports.get_import_log!(id)

    case import_log.upload_key do
      nil -> not_found(conn, "This run's upload was consumed and deleted.")
      key -> send_upload(conn, import_log, key)
    end
  end

  defp send_upload(conn, import_log, key) do
    scratch = Path.join(System.tmp_dir!(), "import_upload_#{System.unique_integer([:positive])}")
    local_path = Path.join(scratch, Path.basename(key))

    try do
      with :ok <- Upload.fetch_to(key, local_path),
           {:ok, content} <- File.read(local_path) do
        filename = "import-#{import_log.id}-upload#{Path.extname(key)}"
        send_download(conn, {:binary, content}, filename: filename)
      else
        {:error, _reason} -> not_found(conn, "The upload could not be read from storage.")
      end
    after
      File.rm_rf(scratch)
    end
  end

  defp not_found(conn, message) do
    conn
    |> put_status(:not_found)
    |> text(message)
  end
end
