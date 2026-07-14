defmodule Kjogvi.Datasets.LocalAdapter do
  @moduledoc """
  Stores dataset snapshots as plain files under the configured `:path`
  directory. The default adapter — dev and test round-trip local CSV files
  and cannot touch the prod snapshots.

  With `:otp_app` set, `:path` is resolved under that app's `priv` directory
  via `Application.app_dir/2` — an absolute path, so it points at the same
  files no matter the working directory the app was launched from (umbrella
  root, `apps/kjogvi`, `apps/kjogvi_web`). Without `:otp_app`, `:path` is used
  as-is (relative to the cwd), which tests rely on to point at a temp dir.
  """

  @behaviour Kjogvi.Datasets.Adapter

  @impl true
  def configured?(config) do
    config[:path] not in [nil, ""]
  end

  @impl true
  def write(config, key, content) do
    path = full_path(config, key)

    with :ok <- File.mkdir_p(Path.dirname(path)) do
      File.write(path, content)
    end
  end

  @impl true
  def read(config, key) do
    File.read(full_path(config, key))
  end

  @impl true
  def last_modified(config, key) do
    with {:ok, %File.Stat{mtime: mtime}} <- File.stat(full_path(config, key), time: :universal) do
      {:ok, mtime |> NaiveDateTime.from_erl!() |> DateTime.from_naive!("Etc/UTC")}
    end
  end

  defp full_path(config, key) do
    Path.join(root(config), key)
  end

  defp root(config) do
    path = Keyword.fetch!(config, :path)

    case Keyword.get(config, :otp_app) do
      nil -> path
      otp_app -> Application.app_dir(otp_app, path)
    end
  end
end
