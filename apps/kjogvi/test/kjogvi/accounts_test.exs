defmodule Kjogvi.UsersTest do
  use Kjogvi.DataCase, async: true

  alias Kjogvi.Accounts

  import Kjogvi.AccountsFixtures
  alias Kjogvi.Accounts.User
  alias Kjogvi.Accounts.UserToken

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user_by_email(user.email)
    end
  end

  describe "get_user_by_nickname/1" do
    test "does not return the user if the nickname does not exist" do
      refute Accounts.get_user_by_nickname("unknown")
    end

    test "returns the user if the nickname exists" do
      %{id: id} = user_fixture(nickname: "birder")
      assert %User{id: ^id} = Accounts.get_user_by_nickname("birder")
    end

    test "matches case-insensitively against the downcased nickname" do
      %{id: id} = user_fixture(nickname: "birder")
      assert %User{id: ^id} = Accounts.get_user_by_nickname("BiRdEr")
    end
  end

  describe "suggest_nickname_from_email/1" do
    test "uses the downcased local part of the email" do
      assert Accounts.suggest_nickname_from_email("BirdNerd@example.com") == "birdnerd"
    end

    test "replaces illegal characters with underscores" do
      assert Accounts.suggest_nickname_from_email("john.doe+tag@example.com") == "john_doe_tag"
    end

    test "appends a numeric suffix when the nickname is already taken" do
      user_fixture(nickname: "birder")

      nickname = Accounts.suggest_nickname_from_email("birder@example.com")

      assert nickname =~ ~r/^birder-\d{5}$/
      refute Accounts.get_user_by_nickname(nickname)
    end

    test "pads a too-short local part to the minimum length" do
      assert Accounts.suggest_nickname_from_email("ab@example.com") == "ab_"
      assert Accounts.suggest_nickname_from_email("a@example.com") == "a__"
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the user if the password is not valid" do
      user = user_fixture()
      refute Accounts.get_user_by_email_and_password(user.email, "invalid")
    end

    test "returns the user if the email and password are valid" do
      %{id: id} = user = user_fixture()

      assert %User{id: ^id} =
               Accounts.get_user_by_email_and_password(user.email, valid_user_password())
    end

    test "does not return the user if login is disabled" do
      user = user_fixture()
      :ok = Accounts.disable_user_login(user)

      refute Accounts.get_user_by_email_and_password(user.email, valid_user_password())
    end

    test "returns the user again once login is re-enabled" do
      %{id: id} = user = user_fixture()
      :ok = Accounts.disable_user_login(user)
      :ok = Accounts.enable_user_login(user)

      assert %User{id: ^id} =
               Accounts.get_user_by_email_and_password(user.email, valid_user_password())
    end
  end

  describe "disable_user_login/1" do
    test "marks login as disabled" do
      user = user_fixture()

      :ok = Accounts.disable_user_login(user)

      assert Accounts.login_disabled?(user)
    end

    test "ends the user's active sessions" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)

      :ok = Accounts.disable_user_login(user)

      refute Accounts.get_user_by_session_token(token)
    end

    test "leaves other users' sessions alone" do
      user = user_fixture()
      other = user_fixture()
      other_token = Accounts.generate_user_session_token(other)

      :ok = Accounts.disable_user_login(user)

      assert Accounts.get_user_by_session_token(other_token)
    end
  end

  describe "enable_user_login/1" do
    test "clears the disabled flag" do
      user = user_fixture()
      :ok = Accounts.disable_user_login(user)

      :ok = Accounts.enable_user_login(user)

      refute Accounts.login_disabled?(user)
    end
  end

  describe "get_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!(-1)
      end
    end

    test "returns the user with the given id" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user!(user.id)
    end
  end

  describe "list_users_by_lifelist_size/1" do
    defp observe_species(user, taxon) do
      checklist = insert(:checklist, user: user)
      insert(:observation, checklist: checklist, taxon_key: Ornitho.Schema.Taxon.key(taxon))
    end

    test "orders users by number of distinct public species, descending" do
      {taxon1, _} = create_species_taxon_with_page()
      {taxon2, _} = create_species_taxon_with_page()

      one_species = user_fixture(nickname: "one")
      observe_species(one_species, taxon1)

      two_species = user_fixture(nickname: "two")
      observe_species(two_species, taxon1)
      observe_species(two_species, taxon2)

      assert [%{nickname: "two", lifelist_size: 2}, %{nickname: "one", lifelist_size: 1}] =
               Accounts.list_users_by_lifelist_size()
    end

    test "counts each species once even with multiple observations" do
      {taxon, _} = create_species_taxon_with_page()
      user = user_fixture()
      observe_species(user, taxon)
      observe_species(user, taxon)

      assert [%{id: id, lifelist_size: 1}] = Accounts.list_users_by_lifelist_size()
      assert id == user.id
    end

    test "excludes unreported and hidden observations" do
      {taxon, _} = create_species_taxon_with_page()
      {visible_taxon, _} = create_species_taxon_with_page()
      user = user_fixture()
      checklist = insert(:checklist, user: user)

      insert(:observation,
        checklist: checklist,
        taxon_key: Ornitho.Schema.Taxon.key(taxon),
        unreported: true
      )

      insert(:observation,
        checklist: checklist,
        taxon_key: Ornitho.Schema.Taxon.key(taxon),
        hidden: true
      )

      observe_species(user, visible_taxon)

      assert [%{lifelist_size: 1}] = Accounts.list_users_by_lifelist_size()
    end

    test "omits users with no public species" do
      user_fixture()
      assert Accounts.list_users_by_lifelist_size() == []
    end

    test "respects the :limit option" do
      {taxon, _} = create_species_taxon_with_page()
      for n <- 1..3, do: observe_species(user_fixture(nickname: "birder#{n}"), taxon)

      assert length(Accounts.list_users_by_lifelist_size(limit: 2)) == 2
    end
  end

  describe "list_users_for_admin/2" do
    defp admin_nicknames(page), do: page.entries |> Enum.map(& &1.nickname)

    test "lists all users ordered by nickname when no term is given" do
      user_fixture(nickname: "charlie")
      user_fixture(nickname: "alice")
      user_fixture(nickname: "bob")

      assert ["alice", "bob", "charlie"] =
               Accounts.list_users_for_admin() |> admin_nicknames()
    end

    test "filters by nickname substring, case-insensitively" do
      user_fixture(nickname: "alice")
      user_fixture(nickname: "bob")

      assert ["alice"] = Accounts.list_users_for_admin("ALI") |> admin_nicknames()
    end

    test "filters by display name substring" do
      user_fixture(nickname: "alice", display_name: "Wonderland")
      user_fixture(nickname: "bob", display_name: "Builder")

      assert ["alice"] = Accounts.list_users_for_admin("wonder") |> admin_nicknames()
    end

    test "a blank term lists everyone" do
      user_fixture(nickname: "alice")
      user_fixture(nickname: "bob")

      assert length(Accounts.list_users_for_admin("   ").entries) == 2
    end

    test "paginates" do
      for n <- 1..3, do: user_fixture(nickname: "birder#{n}")

      page = Accounts.list_users_for_admin("", %{page: 1, page_size: 2})

      assert length(page.entries) == 2
      assert page.total_entries == 3
      assert page.total_pages == 2
    end
  end

  describe "count_users/0" do
    test "counts all registered users" do
      assert Accounts.count_users() == 0
      user_fixture()
      user_fixture()
      assert Accounts.count_users() == 2
    end
  end

  describe "login_disabled_ids/1" do
    test "returns the ids of users whose login is disabled" do
      disabled = user_fixture()
      active = user_fixture()
      Accounts.disable_user_login(disabled)

      ids = Accounts.login_disabled_ids([disabled, active])

      assert MapSet.member?(ids, disabled.id)
      refute MapSet.member?(ids, active.id)
    end
  end

  describe "register_user/1" do
    test "requires email, password and nickname to be set" do
      {:error, changeset} = Accounts.register_user(%{})

      assert %{
               password: ["can't be blank"],
               email: ["can't be blank"],
               nickname: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates nickname format and length" do
      {:error, changeset} = Accounts.register_user(%{nickname: "ab"})
      assert "should be at least 3 character(s)" in errors_on(changeset).nickname

      {:error, changeset} = Accounts.register_user(%{nickname: String.duplicate("a", 21)})
      assert "should be at most 20 character(s)" in errors_on(changeset).nickname

      {:error, changeset} = Accounts.register_user(%{nickname: "bad nick!"})

      assert "must contain only letters, digits, hyphens and underscores" in errors_on(changeset).nickname
    end

    test "forces nickname to lowercase" do
      {:ok, user} = Accounts.register_user(valid_user_attributes(nickname: "JohnDoe"))
      assert user.nickname == "johndoe"
    end

    test "validates nickname uniqueness ignoring case" do
      %{nickname: nickname} = user_fixture()

      {:error, changeset} =
        Accounts.register_user(valid_user_attributes(nickname: String.upcase(nickname)))

      assert "has already been taken" in errors_on(changeset).nickname
    end

    test "accepts an optional display_name and validates its format" do
      {:ok, user} = Accounts.register_user(valid_user_attributes(display_name: "Vitalii K."))
      assert user.display_name == "Vitalii K."

      {:ok, user} = Accounts.register_user(valid_user_attributes())
      assert is_nil(user.display_name)

      {:error, changeset} =
        Accounts.register_user(valid_user_attributes(display_name: "no_underscores"))

      assert "must contain only letters, spaces and common punctuation" in errors_on(changeset).display_name
    end

    test "validates email and password when given" do
      {:error, changeset} = Accounts.register_user(%{email: "not valid", password: "not valid"})

      assert %{
               email: ["Must have the @ sign and no spaces."],
               password: ["should be 12–72 characters."]
             } = errors_on(changeset)
    end

    test "validates maximum values for email and password for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.register_user(%{email: too_long, password: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be 12–72 characters." in errors_on(changeset).password
    end

    test "validates email uniqueness" do
      %{email: email} = user_fixture()
      {:error, changeset} = Accounts.register_user(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = Accounts.register_user(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers users with a hashed password" do
      email = unique_user_email()
      {:ok, user} = Accounts.register_user(valid_user_attributes(email: email))
      assert user.email == email
      assert is_binary(user.hashed_password)
      assert is_nil(user.confirmed_at)
      assert is_nil(user.password)
    end

    test "assigns a distinct public token to each user" do
      {:ok, user1} = Accounts.register_user(valid_user_attributes())
      {:ok, user2} = Accounts.register_user(valid_user_attributes())

      assert is_binary(user1.public_token)
      assert user1.public_token != ""
      assert user1.public_token != user2.public_token
    end

    test "stamps the site default taxonomy" do
      {:ok, user} = Accounts.register_user(valid_user_attributes())
      assert user.default_book_signature == "ebird/v2025"
    end
  end

  describe "register_admin/1" do
    test "derives the nickname from the part of the email before the @ sign when not given" do
      {:ok, user} =
        Accounts.register_admin(
          valid_user_attributes(email: "alice@example.com")
          |> Map.delete(:nickname)
        )

      assert user.nickname == "alice"
    end

    test "uses the nickname passed in the attributes when provided" do
      {:ok, user} =
        Accounts.register_admin(
          valid_user_attributes(email: "bob@example.com", nickname: "someoneelse")
        )

      assert user.nickname == "someoneelse"
    end

    test "grants the admin role" do
      {:ok, user} = Accounts.register_admin(valid_user_attributes(email: "carol@example.com"))
      assert Kjogvi.Accounts.admin_role() in user.roles
    end

    test "stamps the site default taxonomy" do
      {:ok, user} = Accounts.register_admin(valid_user_attributes(email: "dave@example.com"))
      assert user.default_book_signature == "ebird/v2025"
    end

    test "sanitizes disallowed characters in the derived nickname" do
      {:ok, user} =
        Accounts.register_admin(
          valid_user_attributes(email: "a.b@example.com")
          |> Map.delete(:nickname)
        )

      assert user.nickname == "a_b"
    end

    test "pads a too-short derived nickname to the minimum length" do
      {:ok, user} =
        Accounts.register_admin(
          valid_user_attributes(email: "ab@example.com")
          |> Map.delete(:nickname)
        )

      assert user.nickname == "ab_"
    end
  end

  describe "list_admins/0" do
    test "returns only admins, ordered by nickname" do
      {:ok, _} =
        Accounts.register_admin(valid_user_attributes(email: "zoe@example.com", nickname: "zoe"))

      {:ok, _} =
        Accounts.register_admin(valid_user_attributes(email: "amy@example.com", nickname: "amy"))

      # A non-admin must be excluded.
      Kjogvi.AccountsFixtures.user_fixture(nickname: "bob")

      assert ["amy", "zoe"] = Accounts.list_admins() |> Enum.map(& &1.nickname)
    end

    test "returns an empty list when there are no admins" do
      Kjogvi.AccountsFixtures.user_fixture()
      assert Accounts.list_admins() == []
    end
  end

  describe "change_user_registration/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_registration(%User{})
      assert changeset.required == [:nickname, :password, :email]
    end

    test "allows fields to be set" do
      email = unique_user_email()
      password = valid_user_password()

      changeset =
        Accounts.change_user_registration(
          %User{},
          valid_user_attributes(email: email, password: password)
        )

      assert changeset.valid?
      assert get_change(changeset, :email) == email
      assert get_change(changeset, :password) == password
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "change_user_email/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_email(%User{})
      assert changeset.required == [:email]
    end
  end

  describe "apply_user_email/3" do
    setup do
      %{user: user_fixture()}
    end

    test "requires email to change", %{user: user} do
      {:error, changeset} = Accounts.apply_user_email(user, valid_user_password(), %{})
      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{user: user} do
      {:error, changeset} =
        Accounts.apply_user_email(user, valid_user_password(), %{email: "not valid"})

      assert %{email: ["Must have the @ sign and no spaces."]} = errors_on(changeset)
    end

    test "validates maximum value for email for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.apply_user_email(user, valid_user_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", %{user: user} do
      %{email: email} = user_fixture()
      password = valid_user_password()

      {:error, changeset} = Accounts.apply_user_email(user, password, %{email: email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates current password", %{user: user} do
      {:error, changeset} =
        Accounts.apply_user_email(user, "invalid", %{email: unique_user_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{user: user} do
      email = unique_user_email()
      {:ok, user} = Accounts.apply_user_email(user, valid_user_password(), %{email: email})
      assert user.email == email
      assert Accounts.get_user!(user.id).email != email
    end
  end

  describe "deliver_user_update_email_instructions/3" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(user, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "change:current@example.com"
    end
  end

  describe "update_user_email/2" do
    setup do
      user = user_fixture()
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{user: user, token: token, email: email}
    end

    test "updates the email with a valid token", %{user: user, token: token, email: email} do
      assert Accounts.update_user_email(user, token) == :ok
      changed_user = Repo.get!(User, user.id)
      assert changed_user.email != user.email
      assert changed_user.email == email
      assert changed_user.confirmed_at
      assert changed_user.confirmed_at != user.confirmed_at
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email with invalid token", %{user: user} do
      assert Accounts.update_user_email(user, "oops") == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if user email changed", %{user: user, token: token} do
      assert Accounts.update_user_email(%{user | email: "current@example.com"}, token) == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.update_user_email(user, token) == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "change_user_password/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_password(%User{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Accounts.change_user_password(%User{}, %{
          "password" => "new valid password"
        })

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_user_password/3" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(user, valid_user_password(), %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be 12–72 characters."],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_user_password(user, valid_user_password(), %{password: too_long})

      assert "should be 12–72 characters." in errors_on(changeset).password
    end

    test "validates current password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(user, "invalid", %{password: valid_user_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{user: user} do
      {:ok, user} =
        Accounts.update_user_password(user, valid_user_password(), %{
          password: "new valid password"
        })

      assert is_nil(user.password)
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Accounts.generate_user_session_token(user)

      {:ok, _} =
        Accounts.update_user_password(user, valid_user_password(), %{
          password: "new valid password"
        })

      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "session"

      # Creating the same token for another user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%UserToken{
          token: user_token.token,
          user_id: user_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert session_user = Accounts.get_user_by_session_token(token)
      assert session_user.id == user.id
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "delete_user_session_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      assert Accounts.delete_user_session_token(token) == :ok
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "deliver_user_confirmation_instructions/2" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_confirmation_instructions(user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "confirm"
    end
  end

  describe "confirm_user/1" do
    setup do
      user = user_fixture()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_confirmation_instructions(user, url)
        end)

      %{user: user, token: token}
    end

    test "confirms the email with a valid token", %{user: user, token: token} do
      assert {:ok, confirmed_user} = Accounts.confirm_user(token)
      assert confirmed_user.confirmed_at
      assert confirmed_user.confirmed_at != user.confirmed_at
      assert Repo.get!(User, user.id).confirmed_at
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not confirm with invalid token", %{user: user} do
      assert Accounts.confirm_user("oops") == :error
      refute Repo.get!(User, user.id).confirmed_at
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not confirm email if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.confirm_user(token) == :error
      refute Repo.get!(User, user.id).confirmed_at
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "deliver_user_reset_password_instructions/2" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_reset_password_instructions(user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "reset-password"
    end
  end

  describe "get_user_by_reset_password_token/1" do
    setup do
      user = user_fixture()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_reset_password_instructions(user, url)
        end)

      %{user: user, token: token}
    end

    test "returns the user with valid token", %{user: %{id: id}, token: token} do
      assert %User{id: ^id} = Accounts.get_user_by_reset_password_token(token)
      assert Repo.get_by(UserToken, user_id: id)
    end

    test "does not return the user with invalid token", %{user: user} do
      refute Accounts.get_user_by_reset_password_token("oops")
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not return the user if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_user_by_reset_password_token(token)
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "reset_user_password/2" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Accounts.reset_user_password(user, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be 12–72 characters."],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.reset_user_password(user, %{password: too_long})
      assert "should be 12–72 characters." in errors_on(changeset).password
    end

    test "updates the password", %{user: user} do
      {:ok, updated_user} = Accounts.reset_user_password(user, %{password: "new valid password"})
      assert is_nil(updated_user.password)
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Accounts.generate_user_session_token(user)
      {:ok, _} = Accounts.reset_user_password(user, %{password: "new valid password"})
      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "inspect/2 for the User module" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
