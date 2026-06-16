defmodule Kjogvi.Images do
  @moduledoc """
  Context for managing bird images.

  Images are standalone entities owned by a user. They may optionally be linked
  to observations (many-to-many); all observations linked to one image must
  belong to the same card.
  """

  import Ecto.Query

  alias Kjogvi.Repo
  alias Kjogvi.Images.Image
  alias Kjogvi.Images.ImageObservation
  alias Kjogvi.Images.VixProcessor

  @doc """
  Lists a user's images, newest first, as a paginated `Scrivener.Page`.
  """
  def list_images(user, %{page: page, page_size: page_size}) do
    Image
    |> where([i], i.user_id == ^user.id)
    |> order_by([i], desc: i.inserted_at, desc: i.id)
    |> preload(:user)
    |> Repo.paginate(page: page, page_size: page_size)
  end

  @doc """
  Lists images from all users, newest first, as a paginated `Scrivener.Page`.

  Used for the public gallery; the owning user is preloaded for display.
  """
  def list_public_images(%{page: page, page_size: page_size}) do
    Image
    |> order_by([i], desc: i.inserted_at, desc: i.id)
    |> preload(:user)
    |> Repo.paginate(page: page, page_size: page_size)
  end

  @doc """
  Lists images for the gallery, choosing which images to show from the scope's
  area:

    * `:user` - the images of the scope's `subject_user`.
    * `:community` - images from all users.

  The query is derived from the area, not chosen by the caller.
  """
  def list_images_for_scope(%{area: :user, subject_user: subject_user}, pagination) do
    list_images(subject_user, pagination)
  end

  def list_images_for_scope(%{area: :community}, pagination) do
    list_public_images(pagination)
  end

  @doc """
  Fetches one of the user's images by id, raising if it is missing or owned by
  someone else.
  """
  def get_image!(user, id) do
    Image
    |> where([i], i.user_id == ^user.id)
    |> preload(:user)
    |> Repo.get!(id)
  end

  @doc """
  Fetches an image by slug, or `nil`.
  """
  def get_image_by_slug(slug) do
    Repo.get_by(Image, slug: slug)
  end

  @doc """
  Builds a changeset for an image, for use with `to_form/1`.
  """
  def change_image(%Image{} = image, attrs \\ %{}) do
    Image.changeset(image, attrs)
  end

  @doc """
  Creates an image for the user.

  Expects a `%Plug.Upload{}` under the `"file"` key. Dimensions and EXIF date
  are extracted from the uploaded file (before storage, so it works for any
  backend) and saved into `extras`.

  Callers that already extracted the file's metadata (e.g. to seed a form on
  upload) can pass it as `extras` to avoid re-reading the file; when omitted it
  is extracted here.

  The file is stored to the configured backend as part of the insert. A storage
  failure (e.g. missing S3 credentials or no write permission) returns
  `{:error, :storage_failed}` so callers can show a generic message; validation
  failures still return `{:error, %Ecto.Changeset{}}`.
  """
  def create_image(user, attrs, extras \\ nil) do
    extras = extras || extract_metadata(attrs["file"])

    attrs =
      attrs
      |> Map.put("user_id", user.id)
      |> Map.put("storage_backend", current_storage_backend())

    # Set the user association on the base struct so it rides along as the
    # waffle scope: the uploader needs the user's public_token to build the
    # storage path.
    with_storage_guard(fn ->
      %Image{extras: extras, user: user}
      |> Image.changeset(attrs)
      |> Repo.insert()
    end)
  end

  @doc """
  Updates an image's editable metadata. Does not touch the stored file.
  """
  def update_image(%Image{} = image, attrs) do
    image
    |> Image.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Replaces an image's stored file with a new upload, keeping the same record.

  Expects a `%Plug.Upload{}` under the `"file"` key. The new file's dimensions
  and EXIF date are re-extracted into `extras`, and the image is re-stamped with
  the current storage backend.

  The old stored objects are deliberately *not* removed. The storage key is
  derived from the uploaded basename, so replacing with a differently-named file
  stores the new objects under new keys and leaves the previous original and
  variants in the backend (replacing with the same basename overwrites them in
  place). Recorded URLs always point at the now-current `file`, so the orphaned
  objects are simply unreferenced; clean them up out of band if desired.

  Callers that already extracted the file's metadata can pass it as `extras` to
  avoid re-reading the file; when omitted it is extracted here.

  Like `create_image/2`, a storage failure returns `{:error, :storage_failed}`.
  """
  def replace_image_file(%Image{} = image, attrs, extras \\ nil) do
    # The user carries the public_token segment of the storage path; the
    # uploader needs it as the waffle scope to store the new file.
    image = maybe_preload_user(image)

    extras = extras || extract_metadata(attrs["file"])

    attrs = Map.put(attrs, "storage_backend", current_storage_backend())

    with_storage_guard(fn ->
      image
      |> Image.changeset(attrs)
      |> Image.metadata_changeset(extras)
      |> Repo.update()
    end)
  end

  # Runs a waffle-backed insert/update and normalizes storage failures.
  #
  # The file is uploaded to the backend during `cast_attachments` (inside the
  # changeset). When the store fails gracefully, waffle's Ecto type turns it into
  # a generic `:file` changeset error ("is invalid"), so the op returns
  # `{:error, changeset}` with an error on `:file`.
  #
  # The `:file` field is never validated for content here (no `required`, no
  # format) — the only way it gets an error is a failed store — so an error on it
  # unambiguously means a storage failure, which collapses to
  # `{:error, :storage_failed}`. Genuine validation failures (slug, etc.) pass
  # through as `{:error, changeset}`.
  defp with_storage_guard(fun) do
    case fun.() do
      {:ok, image} ->
        {:ok, image}

      {:error, %Ecto.Changeset{} = changeset} ->
        if Keyword.has_key?(changeset.errors, :file) do
          {:error, :storage_failed}
        else
          {:error, changeset}
        end
    end
  end

  @doc """
  Deletes an image along with its stored files.
  """
  def delete_image(%Image{} = image) do
    if image.file do
      Kjogvi.Images.Uploader.delete({image.file, image})
    end

    Repo.delete(image)
  end

  @doc """
  Replaces the set of observations linked to an image.

  Only the image owner's own observations are linked: any id whose observation
  belongs to a card of another user is silently dropped before validation (an
  authorization guard on the write path, not just the picker UI). An image must
  then have at least one observation and they must all belong to the same card
  (both enforced by `Image.observations_changeset/2`), so an empty list — or a
  list of only foreign ids — returns an error changeset.
  """
  def attach_observations(%Image{} = image, observation_ids) when is_list(observation_ids) do
    observations = load_observations(image.user_id, observation_ids)

    image
    |> Repo.preload(:observations)
    |> Image.observations_changeset(observations)
    |> Repo.update()
  end

  @doc """
  Loads observations by id for display in the image's observation picker,
  hydrating each with its taxon/species and preloading the card (with location).

  Used to render the "currently attached/selected" tiles from a list of ids the
  caller is staging. Preserves the order of `observation_ids`. Restricts to the
  user's own observations.
  """
  def get_observations_for_display(user, observation_ids) when is_list(observation_ids) do
    observations =
      Kjogvi.Birding.Observation
      |> join(:inner, [obs], c in assoc(obs, :card))
      |> where([obs, c], obs.id in ^observation_ids and c.user_id == ^user.id)
      |> preload([_obs, _c], card: :location)
      |> Repo.all()
      |> Kjogvi.Birding.preload_taxa_and_species()
      |> Map.new(&{&1.id, &1})

    observation_ids
    |> Enum.map(&observations[&1])
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Searches a user's observations for the image observation picker.

  The typed `query` is resolved to matching taxa (via `Search.Taxon`); the
  user's observations of those taxa are then returned, hydrated for display.

  Scoping (most specific wins):

    * `card_id` — restrict to that one card. Used once an observation is
      selected: all of an image's observations must share a card, so the picker
      locks subsequent search to it.
    * `date` (a `Date`) — restrict to observations on cards of that day.
    * neither — the most recent matching observations across all cards.

  Results are capped (`limit`, default 10) and ordered newest card first.

  Returns hydrated observation structs (with `:taxon`, `:species`, and the
  preloaded `:card`), ready to render as tiles. Returns `[]` for a blank query.
  """
  def search_observations_for_image(user, opts) do
    query = opts |> Map.get(:query, "") |> to_string() |> String.trim()
    card_id = Map.get(opts, :card_id)
    date = Map.get(opts, :date)
    limit = Map.get(opts, :limit, 10)

    taxon_keys =
      case query do
        "" -> []
        text -> text |> Kjogvi.Search.Taxon.search_taxa(user) |> Enum.map(& &1.key)
      end

    if taxon_keys == [] do
      []
    else
      Kjogvi.Birding.Observation
      |> join(:inner, [obs], c in assoc(obs, :card))
      |> where([obs, c], c.user_id == ^user.id and obs.taxon_key in ^taxon_keys)
      |> maybe_scope(card_id, date)
      |> order_by([_obs, c], desc: c.observ_date, desc: c.id)
      |> limit(^limit)
      |> preload([_obs, _c], card: :location)
      |> Repo.all()
      |> Kjogvi.Birding.preload_taxa_and_species()
    end
  end

  defp maybe_scope(query, card_id, _date) when not is_nil(card_id) do
    where(query, [obs, _c], obs.card_id == ^card_id)
  end

  defp maybe_scope(query, _card_id, %Date{} = date) do
    where(query, [_obs, c], c.observ_date == ^date)
  end

  defp maybe_scope(query, _card_id, _date), do: query

  @doc """
  Lists images linked to any observation on the given card.
  """
  def list_images_for_card(card_id) do
    Image
    |> join(:inner, [i], io in ImageObservation, on: io.image_id == i.id)
    |> join(:inner, [_i, io], obs in Kjogvi.Birding.Observation, on: obs.id == io.observation_id)
    |> where([_i, _io, obs], obs.card_id == ^card_id)
    |> distinct([i], i.id)
    |> order_by([i], asc: i.sort_order, asc: i.id)
    |> Repo.all()
  end

  @doc """
  Public URL for the given version of the image (defaults to `:medium`).

  The URL is built from the image's own recorded `storage_backend`, not the
  backend the running environment uploads with. This keeps every image
  resolvable when a database is shared across environments — a prod-S3 image
  renders against the prod host even on a local dev box, and vice versa.

  The image's user must be available (it carries the `public_token` segment of
  the path); it is preloaded here if the caller hasn't already done so.
  """
  def url(image, version \\ :medium)

  def url(%Image{file: nil, legacy_url: legacy_url}, _version) when not is_nil(legacy_url) do
    legacy_url
  end

  def url(%Image{file: nil}, _version), do: nil

  def url(%Image{} = image, version) do
    image = maybe_preload_user(image)
    key = Kjogvi.Images.Uploader.s3_key(version, {image.file, image})

    [backend_host(image.storage_backend), "/", key, cache_buster(image.file)]
    |> Enum.join()
  end

  defp maybe_preload_user(%Image{user: %Kjogvi.Accounts.User{}} = image), do: image
  defp maybe_preload_user(%Image{} = image), do: Repo.preload(image, :user)

  # The host prefix for the image's backend. `local` has no host: its files are
  # served by the endpoint at the relative `/uploads/...` path, so the URL is
  # host-relative (begins with the leading "/" added by the caller).
  defp backend_host(backend) do
    :kjogvi
    |> Application.get_env(:images, [])
    |> Keyword.get(:hosts, %{})
    |> Map.get(backend)
    |> case do
      nil -> ""
      host -> String.trim_trailing(host, "/")
    end
  end

  # Waffle stamps each upload with an `updated_at`, surfaced in URLs as a
  # `?<unix>` query string. S3 ignores it when locating the object, but it busts
  # client/CDN caches when an image's file is replaced (the key is otherwise
  # stable). Mirror that here since we build the URL ourselves.
  defp cache_buster(%{updated_at: %{} = updated_at}) do
    "?#{updated_at |> NaiveDateTime.truncate(:second) |> to_unix()}"
  end

  defp cache_buster(_), do: ""

  defp to_unix(naive), do: naive |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()

  defp current_storage_backend do
    :kjogvi
    |> Application.get_env(:images, [])
    |> Keyword.get(:storage_backend, "local")
  end

  @doc """
  EXIF capture date as a `Date`, or `nil` when absent, from an extras map.

  Lets callers that already have a file's extracted metadata (see
  `extract_metadata/1`) read just the capture date — e.g. to default the
  observation picker's search date on upload, without re-reading the file.
  """
  def exif_date(extras) do
    case Image.exif_date(%Image{extras: extras}) do
      %NaiveDateTime{} = naive -> NaiveDateTime.to_date(naive)
      _ -> nil
    end
  end

  @doc """
  Extracts dimensions and EXIF metadata from a `%Plug.Upload{}`.

  Reads the file via `VixProcessor` and returns a map with string keys matching
  the `extras` jsonb column's round-trip representation; a non-upload (or a read
  failure) yields `%{}`. The upload's MIME type is included as `"content_type"`
  when present. Pass the result to `create_image/3` or `replace_image_file/3` to
  avoid re-reading the file at save.
  """
  def extract_metadata(%{path: path} = upload) do
    case VixProcessor.extract_metadata(path) do
      {:ok, metadata} ->
        metadata
        |> Map.new(fn {key, value} -> {to_string(key), value} end)
        |> maybe_put_content_type(upload)

      _ ->
        %{}
    end
  end

  def extract_metadata(_), do: %{}

  defp maybe_put_content_type(extras, %{content_type: content_type})
       when is_binary(content_type) and content_type != "application/octet-stream" do
    Map.put(extras, "content_type", content_type)
  end

  defp maybe_put_content_type(extras, _upload), do: extras

  defp load_observations(_user_id, []), do: []

  # Restricts to observations on the user's own cards, so a tampered request
  # can't link another user's observations to an image.
  defp load_observations(user_id, observation_ids) do
    Kjogvi.Birding.Observation
    |> join(:inner, [obs], c in assoc(obs, :card))
    |> where([obs, c], obs.id in ^observation_ids and c.user_id == ^user_id)
    |> Repo.all()
  end
end
