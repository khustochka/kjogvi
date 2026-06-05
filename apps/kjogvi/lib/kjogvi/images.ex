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
  Lists a user's images, ordered by `sort_order` then `id`.
  """
  def list_images(user) do
    Image
    |> where([i], i.user_id == ^user.id)
    |> order_by([i], asc: i.sort_order, asc: i.id)
    |> preload(:user)
    |> Repo.all()
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
  """
  def create_image(user, attrs) do
    extras = extract_metadata(attrs["file"])

    attrs =
      attrs
      |> Map.put("user_id", user.id)
      |> Map.put("storage_backend", current_storage_backend())

    # Set the user association on the base struct so it rides along as the
    # waffle scope: the uploader needs the user's public_token to build the
    # storage path.
    %Image{extras: extras, user: user}
    |> Image.changeset(attrs)
    |> Repo.insert()
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
  """
  def replace_image_file(%Image{} = image, attrs) do
    # The user carries the public_token segment of the storage path; the
    # uploader needs it as the waffle scope to store the new file.
    image = maybe_preload_user(image)

    extras = extract_metadata(attrs["file"])

    attrs = Map.put(attrs, "storage_backend", current_storage_backend())

    image
    |> Image.changeset(attrs)
    |> Image.metadata_changeset(extras)
    |> Repo.update()
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
  Replaces the set of observations linked to an image. All observations must
  belong to the same card (enforced by `Image.observations_changeset/2`);
  passing an empty list clears the links.
  """
  def attach_observations(%Image{} = image, observation_ids) when is_list(observation_ids) do
    observations = load_observations(observation_ids)

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

  def url(%Image{file: nil}, _version), do: nil

  def url(%Image{} = image, version) do
    image = maybe_preload_user(image)
    key = Kjogvi.Images.Uploader.s3_key(version, {image.file, image})

    [backend_host(image.storage_backend), "/", key, cache_buster(image.file)]
    |> Enum.join()
  end

  defp maybe_preload_user(%Image{user: %Kjogvi.Users.User{}} = image), do: image
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
  EXIF capture date of an uploaded file as a `Date`, or `nil` when absent.

  Reads the same metadata `create_image/2` extracts (via `VixProcessor`), but
  exposes just the capture date for callers that need it before the image is
  saved — e.g. to default the observation picker's search date on upload.
  """
  def exif_date_from_upload(%Plug.Upload{} = upload) do
    case extract_metadata(upload) do
      %{"exif_date" => value} when is_binary(value) ->
        case NaiveDateTime.from_iso8601(String.replace(value, " ", "T")) do
          {:ok, naive} -> NaiveDateTime.to_date(naive)
          _ -> nil
        end

      _ ->
        nil
    end
  end

  def exif_date_from_upload(_), do: nil

  # Extract metadata from a Plug.Upload before the file is stored. Keys are
  # stringified to match the jsonb column's round-trip representation.
  defp extract_metadata(%Plug.Upload{path: path}) do
    case VixProcessor.extract_metadata(path) do
      {:ok, metadata} ->
        Map.new(metadata, fn {key, value} -> {to_string(key), value} end)

      _ ->
        %{}
    end
  end

  defp extract_metadata(_), do: %{}

  defp load_observations([]), do: []

  defp load_observations(observation_ids) do
    Kjogvi.Birding.Observation
    |> where([obs], obs.id in ^observation_ids)
    |> Repo.all()
  end
end
