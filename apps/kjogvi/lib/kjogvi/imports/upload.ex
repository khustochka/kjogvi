defmodule Kjogvi.Imports.Upload do
  @moduledoc """
  Temporary per-user storage for import source files (e.g. an eBird export
  `.zip`), behind a configurable adapter.

  Unlike `Kjogvi.Datasets` (curated, admin-owned snapshots) and
  `Kjogvi.Images` (permanent, user-facing media), these uploads are
  **ephemeral**: a user hands one in, an import job consumes it, and it is
  deleted — except after a failed run, which retains the file for admin
  review (`Kjogvi.Imports.ImportLog.upload_key`); a bucket lifecycle rule
  must leave retained files enough time to be looked at.
  Files are addressed by an opaque `key` scoped to the owning user
  (`imports/<kind>/<user_id>/<uuid>.<ext>`), so one user's uploads can never
  collide with or be read as another's.

  The base config uses `Kjogvi.Imports.Upload.LocalAdapter` (files under a
  local directory); production switches to `Kjogvi.Imports.Upload.S3Adapter`
  in `runtime.exs` with its own dedicated bucket, kept separate from the
  images bucket so an S3 lifecycle rule can expire abandoned uploads without
  touching permanent media.

      config :kjogvi, Kjogvi.Imports.Upload,
        adapter: Kjogvi.Imports.Upload.LocalAdapter,
        path: "tmp/imports"
  """

  @doc """
  Whether the configured adapter has the settings it needs to reach its
  backing store (e.g. the S3 adapter's bucket).
  """
  def configured? do
    adapter().configured?(config())
  end

  @doc """
  Stores `content` as a `user`-scoped upload of the given `kind` (an atom such
  as `:ebird`) and file `extension` (without the dot), returning the opaque
  `key` the import job later reads it back by.
  """
  def store(user, kind, extension, content) do
    key = build_key(user, kind, extension)

    with :ok <- adapter().write(config(), key, content) do
      {:ok, key}
    end
  end

  @doc """
  Copies the upload at `key` down to `local_path` (creating parent dirs),
  giving an import job a real file on disk to unzip / stream regardless of the
  backing store.
  """
  def fetch_to(key, local_path) do
    with :ok <- File.mkdir_p(Path.dirname(local_path)) do
      adapter().fetch_to(config(), key, local_path)
    end
  end

  @doc """
  Removes the upload at `key`. Succeeds if it is already gone — deletion runs
  after a consumed upload and must not fail a completed import.
  """
  def delete(key) do
    adapter().delete(config(), key)
  end

  defp build_key(user, kind, extension) do
    uuid = Ecto.UUID.generate()
    "imports/#{kind}/#{user.id}/#{uuid}.#{extension}"
  end

  defp adapter do
    Keyword.fetch!(config(), :adapter)
  end

  defp config do
    Application.get_env(:kjogvi, __MODULE__, [])
  end
end
