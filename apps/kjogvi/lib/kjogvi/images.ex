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
