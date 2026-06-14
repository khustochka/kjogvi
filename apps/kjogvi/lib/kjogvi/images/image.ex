defmodule Kjogvi.Images.Image do
  @moduledoc """
  Image schema.

  An image is a standalone entity belonging to a user. It may optionally be
  linked to one or more observations (many-to-many); when linked, all of an
  image's observations must belong to the same card (enforced in the context).

  `extras` holds derived metadata (dimensions, EXIF capture date) and is not
  edited directly by the user.
  """

  use Kjogvi.Schema
  use Waffle.Ecto.Schema

  import Ecto.Changeset

  schema "images" do
    # Opaque, stable identifier used in the storage path (survives slug changes).
    field :token, :string
    field :slug, :string
    field :title, :string
    field :description, :string
    field :sort_order, :integer, default: 100
    field :extras, :map, default: %{}
    field :storage_backend, :string, default: "local"
    # Denormalized: true when more than one observation is attached. Kept in sync
    # by `observations_changeset/2`; not set directly by callers.
    field :multi_species, :boolean, default: false

    field :file, Kjogvi.Images.Uploader.Type
    field :legacy_url, :string

    field :import_source, Ecto.Enum, values: Kjogvi.Types.ImportSource.values()

    belongs_to :user, Kjogvi.Accounts.User

    many_to_many :observations, Kjogvi.Birding.Observation,
      join_through: Kjogvi.Images.ImageObservation,
      on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(image, attrs) do
    image
    |> cast(attrs, [:slug, :title, :description, :sort_order, :storage_backend, :user_id])
    # Assign the token before cast_attachments, since waffle reads it to build
    # the storage path during attachment.
    |> ensure_token()
    |> cast_attachments(attrs, [:file])
    |> default_validations()
  end

  @doc "Creates an image pointing to legacy URL"
  def legacy_changeset(image, attrs) do
    image
    |> cast(attrs, [:slug, :title, :description, :sort_order, :user_id, :legacy_url])
    |> put_change(:storage_backend, "legacy")
    |> validate_required([:legacy_url])
    |> default_validations()
  end

  defp default_validations(changeset) do
    changeset
    |> ensure_token()
    |> validate_required([:slug, :user_id, :storage_backend, :token])
    |> validate_length(:slug, min: 1, max: 255)
    |> validate_number(:sort_order, greater_than_or_equal_to: 0)
    |> unique_constraint(:slug, name: :images_user_id_slug_index)
    |> unique_constraint(:token)
  end

  # Assigns a token on first creation, leaving any existing one intact.
  defp ensure_token(changeset) do
    case get_field(changeset, :token) do
      nil -> put_change(changeset, :token, Kjogvi.Util.Token.generate())
      _ -> changeset
    end
  end

  @doc false
  def metadata_changeset(image, extras) do
    change(image, extras: extras)
  end

  @doc """
  Changeset that replaces the image's linked observations.

  Takes already-loaded `Observation` structs (the caller is responsible for
  loading them) and enforces that

    * an image has at least one observation, and
    * they all belong to the same card.

  Does no database access itself.
  """
  def observations_changeset(image, observations) when is_list(observations) do
    image
    |> change()
    |> put_assoc(:observations, observations)
    # force_change (not put_change): the in-memory struct may carry a stale
    # multi_species that matches the new value yet differs from what's persisted
    # (e.g. re-attaching to an image loaded before a prior change), so we always
    # write the column.
    |> force_change(:multi_species, length(observations) > 1)
    |> validate_at_least_one(observations)
    |> validate_same_card(observations)
  end

  # Temporary product rule: every image must be linked to at least one
  # observation. To allow standalone (observation-less) images later, drop this
  # validation (and its call above).
  defp validate_at_least_one(changeset, []) do
    add_error(changeset, :observations, "can't be empty")
  end

  defp validate_at_least_one(changeset, _observations), do: changeset

  defp validate_same_card(changeset, observations) do
    case observations |> Enum.map(& &1.card_id) |> Enum.uniq() do
      cards when length(cards) <= 1 ->
        changeset

      _ ->
        add_error(changeset, :observations, "must all belong to the same card")
    end
  end

  @doc """
  Pixel dimensions as a `{width, height}` tuple, or `nil` when unknown.
  """
  def dimensions(%__MODULE__{extras: %{"width" => w, "height" => h}}), do: {w, h}
  def dimensions(_), do: nil

  @doc """
  EXIF capture date as a `NaiveDateTime`, or `nil` when absent or unparseable.
  """
  def exif_date(%__MODULE__{extras: %{"exif_date" => value}}) when is_binary(value) do
    case NaiveDateTime.from_iso8601(String.replace(value, " ", "T")) do
      {:ok, naive} -> naive
      _ -> nil
    end
  end

  def exif_date(_), do: nil

  @doc """
  MIME type recorded at upload (or import), or `nil` when unknown.
  """
  def content_type(%__MODULE__{extras: %{"content_type" => value}}) when is_binary(value) do
    value
  end

  def content_type(_), do: nil

  @doc """
  Title carried over from the legacy system, or `nil` when absent.
  """
  def legacy_title(%__MODULE__{extras: %{"legacy_title" => value}}) when is_binary(value) do
    value
  end

  def legacy_title(_), do: nil
end
