defmodule Kjogvi.Accounts.User do
  @moduledoc """
  A schema representing user.
  """

  use Kjogvi.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "users" do
    field :email, :string
    field :nickname, :string
    field :display_name, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :current_password, :string, virtual: true, redact: true
    field :confirmed_at, :utc_datetime_usec
    field :roles, {:array, :string}, default: []
    field :default_book_signature, :string
    # Opaque, stable public identifier (used e.g. in image storage paths).
    field :public_token, :string
    # Legacy dumping-ground column, superseded by UserProfile/UserPreferences.
    # Retained (as an untyped map) only to preserve existing data for a possible
    # later manual migration; no code reads or writes it.
    field :extras, :map

    has_one :preferences, Kjogvi.Accounts.UserPreferences, on_replace: :update

    timestamps(type: :utc_datetime_usec)

    # Public life list size, populated by `Accounts.list_users_by_lifelist_size/1`.
    field :lifelist_size, :integer, virtual: true
  end

  @doc """
  Whether `user` owns `ownable` — any struct carrying a `user_id` (e.g. a
  location or checklist). Unowned records (`user_id: nil`) belong to no one.
  """
  def owns?(%__MODULE__{id: id}, %{user_id: user_id}) when not is_nil(user_id) do
    id == user_id
  end

  def owns?(_user, _ownable), do: false

  @doc """
  A user changeset for registration.

  It is important to validate the length of both email and password.
  Otherwise databases may truncate the email without warnings, which
  could lead to unpredictable or insecure behaviour. Long passwords may
  also be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.

    * `:validate_email` - Validates the uniqueness of the email, in case
      you don't want to validate the uniqueness of the email (like when
      using this changeset for validations on a LiveView form before
      submitting the form), this option can be set to `false`.
      Defaults to `true`.

    * `:validate_email_format` - Validates the email format (presence of an `@`
      sign and no spaces). Set to `false` to defer this check until submit, so a
      LiveView form does not flag an in-progress email as malformed on every
      keystroke. Defaults to `true`.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password, :nickname, :display_name])
    |> validate_email(opts)
    |> validate_password(opts)
    |> validate_nickname(opts)
    |> validate_display_name()
    |> ensure_public_token()
  end

  @doc """
  A changeset for live-validating the registration form.

  Covers only email and password; the nickname is generated from the email by
  `Kjogvi.Accounts.register_user/1`. Supports the same `:validate_email` and
  `:validate_email_format` options as `registration_changeset/3`.
  """
  def registration_validation_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password])
    |> validate_email(opts)
    |> validate_password(Keyword.put(opts, :hash_password, false))
  end

  @doc """
  Changeset for admin.
  """
  def admin_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password, :nickname, :display_name])
    |> put_change(:roles, [Kjogvi.Accounts.admin_role()])
    |> validate_email(opts)
    |> validate_password(opts)
    |> validate_nickname(opts)
    |> validate_display_name()
    |> ensure_public_token()
  end

  # Assigns a public token on first creation, leaving any existing one intact.
  defp ensure_public_token(changeset) do
    case get_field(changeset, :public_token) do
      nil ->
        changeset
        |> put_change(:public_token, Kjogvi.Util.Token.generate())
        |> unique_constraint(:public_token)

      _ ->
        changeset
    end
  end

  @doc """
  Changeset for the user's profile settings: identity fields (`nickname`,
  `display_name`) edited on the Profile tab.
  """
  def profile_settings_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:nickname, :display_name])
    |> validate_nickname(opts)
    |> validate_display_name()
  end

  @doc """
  Changeset for the user's preferences: book signature plus the associated
  `UserPreferences` record (created lazily via `cast_assoc` on first save).
  """
  def preferences_changeset(user, attrs, _opts \\ []) do
    user
    |> cast(attrs, [:default_book_signature])
    |> cast_assoc(:preferences)
  end

  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> maybe_validate_email_format(opts)
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  defp maybe_validate_email_format(changeset, opts) do
    if Keyword.get(opts, :validate_email_format, true) do
      validate_format(changeset, :email, ~r/^[^\s]+@[^\s]+$/,
        message: "Must have the @ sign and no spaces."
      )
    else
      changeset
    end
  end

  @nickname_suffix_range 10_000..99_999

  @doc """
  Suggests a nickname derived from the local part of an email address.

  The part before the `@` is downcased and every character that is not a
  letter, digit, hyphen or underscore is replaced with an underscore, so the
  result satisfies the nickname format. When the suggestion is too short or too
  long it is padded or truncated to fit the allowed length.

  `taken?` is invoked with each candidate; while it returns `true` a random
  numeric suffix (separated by a hyphen) is appended and a fresh candidate is
  tried, guaranteeing the returned nickname is free.
  """
  def suggest_nickname_from_email(email, taken?)
      when is_binary(email) and is_function(taken?, 1) do
    base = nickname_base_from_email(email)

    if taken?.(base) do
      suggest_with_suffix(base, taken?)
    else
      base
    end
  end

  # Downcases the local part, replaces disallowed characters with underscores,
  # and pads/truncates to a valid length so the result satisfies the nickname
  # format. Reserves room for a hyphen and a 5-digit suffix so a suffixed
  # nickname still fits within the 20-character maximum.
  defp nickname_base_from_email(email) do
    email
    |> String.split("@")
    |> List.first()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_-]/, "_")
    |> String.slice(0, 14)
    |> String.pad_trailing(3, "_")
  end

  defp suggest_with_suffix(base, taken?) do
    candidate = "#{base}-#{Enum.random(@nickname_suffix_range)}"

    if taken?.(candidate) do
      suggest_with_suffix(base, taken?)
    else
      candidate
    end
  end

  defp validate_nickname(changeset, opts) do
    changeset
    |> update_change(:nickname, &maybe_downcase/1)
    |> validate_required([:nickname])
    |> validate_length(:nickname, min: 3, max: 20)
    |> validate_format(:nickname, ~r/^[a-z0-9_-]+$/,
      message: "must contain only letters, digits, hyphens and underscores"
    )
    |> maybe_validate_unique_nickname(opts)
  end

  defp maybe_downcase(nil), do: nil
  defp maybe_downcase(value), do: String.downcase(value)

  defp maybe_validate_unique_nickname(changeset, opts) do
    if Keyword.get(opts, :validate_nickname, true) do
      changeset
      |> unsafe_validate_unique(:nickname, Kjogvi.Repo)
      |> unique_constraint(:nickname)
    else
      changeset
    end
  end

  defp validate_display_name(changeset) do
    changeset
    |> update_change(:display_name, &maybe_trim/1)
    |> validate_length(:display_name, max: 50)
    |> validate_format(:display_name, ~r/^[\p{L}\p{M} '.\-]+$/u,
      message: "must contain only letters, spaces and common punctuation"
    )
  end

  defp maybe_trim(nil), do: nil
  defp maybe_trim(value), do: String.trim(value)

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72, message: "should be 12–72 characters.")
    # Examples of additional password validation:
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, Kjogvi.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  @doc """
  A user changeset for changing the password.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = DateTime.utc_now(:microsecond)
    change(user, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%Kjogvi.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  @doc """
  Validates the current password otherwise adds an error to the changeset.
  """
  def validate_current_password(changeset, password) do
    changeset = cast(changeset, %{current_password: password}, [:current_password])

    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end

  def display_name(%{display_name: display_name, nickname: nickname}) do
    display_name || nickname
  end
end
