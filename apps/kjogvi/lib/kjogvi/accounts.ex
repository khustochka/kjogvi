defmodule Kjogvi.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Kjogvi.Repo

  alias Kjogvi.Accounts.User
  alias Kjogvi.Accounts.UserPreferences
  alias Kjogvi.Accounts.UserToken
  alias Kjogvi.Accounts.UserNotifier

  @admin_role "admin"

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by nickname.

  Nicknames are stored downcased, so the lookup downcases its argument to match.

  ## Examples

      iex> get_user_by_nickname("birder")
      %User{}

      iex> get_user_by_nickname("unknown")
      nil

  """
  def get_user_by_nickname(nickname) when is_binary(nickname) do
    Repo.get_by(User, nickname: String.downcase(nickname))
  end

  @doc """
  Suggests an unused nickname derived from an email address.

  Used to prefill the registration form. The suggestion is checked against
  existing users and a random numeric suffix is appended until it is free.

  ## Examples

      iex> suggest_nickname_from_email("john.doe@example.com")
      "john_doe"

  """
  def suggest_nickname_from_email(email) when is_binary(email) do
    User.suggest_nickname_from_email(email, fn nickname ->
      not is_nil(get_user_by_nickname(nickname))
    end)
  end

  @doc """
  Lists all users, ordered by nickname, for the public user directory.
  """
  def list_users do
    User
    |> order_by([u], asc: u.nickname)
    |> Repo.all()
  end

  @doc """
  Lists users ordered by the size of their public life list (number of distinct
  species observed in reportable, non-hidden observations), descending.

  Each returned user has a virtual `lifelist_size` field set. Only users that
  have at least one public species are included.

  ## Options

    * `:limit` - the maximum number of users to return. Defaults to `10`.
  """
  def list_users_by_lifelist_size(opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    counts =
      from o in Kjogvi.Birding.Observation,
        join: c in assoc(o, :checklist),
        join: stm in assoc(o, :species_taxa_mapping),
        where: o.unreported == false and o.hidden == false,
        group_by: c.user_id,
        select: %{user_id: c.user_id, lifelist_size: count(stm.species_page_id, :distinct)}

    from(u in User,
      join: counts in subquery(counts),
      on: counts.user_id == u.id,
      order_by: [desc: counts.lifelist_size, asc: u.nickname],
      limit: ^limit,
      select: %{u | lifelist_size: counts.lifelist_size}
    )
    |> Repo.all()
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(put_suggested_nickname(attrs))
    |> Repo.insert()
  end

  # Generate a free nickname from the email when none is given. Accepts attrs
  # keyed by either strings (form params) or atoms (internal callers), and
  # writes the nickname under the same key style the email uses.
  defp put_suggested_nickname(attrs) do
    with "" <- to_string(fetch_attr(attrs, :nickname)),
         {email_key, email} when is_binary(email) and email != "" <-
           fetch_attr_entry(attrs, :email) do
      nickname_key = if is_atom(email_key), do: :nickname, else: "nickname"
      Map.put(attrs, nickname_key, suggest_nickname_from_email(email))
    else
      _ -> attrs
    end
  end

  defp fetch_attr(attrs, key) do
    Map.get(attrs, key) || Map.get(attrs, to_string(key))
  end

  # Returns the `{key, value}` entry for `key` under either an atom or string
  # key, or `nil` if absent.
  defp fetch_attr_entry(attrs, key) do
    cond do
      Map.has_key?(attrs, key) -> {key, Map.get(attrs, key)}
      Map.has_key?(attrs, to_string(key)) -> {to_string(key), Map.get(attrs, to_string(key))}
      true -> nil
    end
  end

  @doc """
  Register an admin user.

  If no main user exists yet (e.g. the first admin created during initial
  setup), the new admin is marked as the main user.
  """
  def register_admin(attrs) do
    %User{}
    |> User.admin_changeset(put_suggested_nickname(attrs))
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(%User{} = user, attrs \\ %{}, opts \\ []) do
    opts = Keyword.merge([hash_password: false, validate_email: false], opts)
    User.registration_changeset(user, attrs, opts)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for live-validating the registration form.

  Unlike `change_user_registration/3` it skips the nickname, which is generated
  from the email by `register_user/1` rather than entered on the form.
  """
  def change_user_registration_validation(%User{} = user, attrs \\ %{}, opts \\ []) do
    opts = Keyword.merge([validate_email: false], opts)
    User.registration_validation_changeset(user, attrs, opts)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}) do
    User.email_changeset(user, attrs, validate_email: false)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_user_email(user, "valid password", %{email: ...})
      {:ok, %User{}}

      iex> apply_user_email(user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
         %UserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transact(user_email_multi(user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp user_email_multi(user, email, context) do
    changeset =
      user
      |> User.email_changeset(%{email: email})
      |> User.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, [context]))
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/my/settings/security/confirm_email/#{&1})")
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Updates the user password.

  ## Examples

      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %User{}}

      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
    |> Repo.transact()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Updates the user's profile settings (identity fields on the Profile tab).
  """
  def update_user_profile_settings(%User{} = user, attrs) do
    user
    |> User.profile_settings_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates the user's preferences, creating the `UserPreferences` row on first save.
  """
  def update_user_preferences(%User{} = user, attrs) do
    user
    |> Repo.preload(:preferences)
    |> User.preferences_changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, user} ->
        # logbook_settings drives Logbook.recent_entries/2; evict cached logbook feed
        # so it's recomputed against the new settings on next read.
        Kjogvi.Birding.Logbook.Cache.invalidate(user.id)
        {:ok, user}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  The user's preferences, or `UserPreferences.default/0` when none saved yet.
  """
  def get_user_preferences(%User{} = user) do
    Repo.get_by(UserPreferences, user_id: user.id) || UserPreferences.default()
  end

  @doc """
  Preloads the user's `:preferences` association (needed for `cast_assoc` /
  `inputs_for` on the preferences form).
  """
  def preload_preferences(%User{} = user) do
    Repo.preload(user, :preferences)
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.by_token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc ~S"""
  Delivers the confirmation email instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(user, &url(~p"/account/confirm/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed_user, &url(~p"/account/confirm/#{&1}"))
      {:error, :already_confirmed}

  """
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)
      UserNotifier.deliver_confirmation_instructions(user, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a user by the given token.

  If the token matches, the user account is marked as confirmed
  and the token is deleted.
  """
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transact(confirm_user_multi(user)) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, ["confirm"]))
  end

  ## Reset password

  @doc ~S"""
  Delivers the reset password email to the given user.

  ## Examples

      iex> deliver_user_reset_password_instructions(user, &url(~p"/account/reset-password/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset-password")
    Repo.insert!(user_token)
    UserNotifier.deliver_reset_password_instructions(user, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the user by reset password token.

  ## Examples

      iex> get_user_by_reset_password_token("validtoken")
      %User{}

      iex> get_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset-password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Resets the user password.

  ## Examples

      iex> reset_user_password(user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %User{}}

      iex> reset_user_password(user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
    |> Repo.transact()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  ## Roles

  @doc """
  String representation of admin role.
  """
  def admin_role do
    @admin_role
  end

  @doc """
  Returns true if user is an admin, false otherwise.
  """
  def admin?(%User{roles: roles}) do
    @admin_role in roles
  end

  def admins do
    from u in User, where: ^admin_role() in u.roles
  end

  @admin_exists_key {__MODULE__, :admin_exists}

  @doc """
  Whether at least one admin user exists. Gates the initial setup flow.

  The positive result is latched in `:persistent_term` on first success and
  never recomputed: once an admin exists it is assumed to exist forever (admin
  deletion is not accounted for). Until then the database is queried on every
  call, so the first admin created during setup flips the result.

  Latching is skipped when the `:latch_admin_exists` config is `false` (the test
  setting), so every call hits the per-test sandboxed database and concurrent
  tests stay isolated despite the latch being process-global.
  """
  def admin_exists? do
    :persistent_term.get(@admin_exists_key, false) || refresh_admin_exists()
  end

  defp refresh_admin_exists do
    if Repo.exists?(admins()) do
      if Application.get_env(:kjogvi, :latch_admin_exists, true) do
        :persistent_term.put(@admin_exists_key, true)
      end

      true
    else
      false
    end
  end
end
