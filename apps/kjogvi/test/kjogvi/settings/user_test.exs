defmodule Kjogvi.Settings.UserTest do
  use Kjogvi.DataCase, async: true

  import Kjogvi.AccountsFixtures

  alias Kjogvi.Settings

  describe "fetch/2" do
    test "falls back to the schema default when no row exists" do
      user = user_fixture()

      assert Settings.User.fetch(user, :login_disabled) == false
    end

    test "a stored row overrides the default" do
      user = user_fixture()
      {:ok, _} = Settings.User.put(user, :login_disabled, true)

      assert Settings.User.fetch(user, :login_disabled) == true
    end

    test "settings are per user" do
      disabled = user_fixture()
      other = user_fixture()
      {:ok, _} = Settings.User.put(disabled, :login_disabled, true)

      assert Settings.User.fetch(disabled, :login_disabled) == true
      assert Settings.User.fetch(other, :login_disabled) == false
    end
  end

  describe "put/3" do
    test "upserts rather than inserting a second row" do
      user = user_fixture()

      {:ok, _} = Settings.User.put(user, :login_disabled, true)
      {:ok, _} = Settings.User.put(user, :login_disabled, false)

      assert Settings.User.fetch(user, :login_disabled) == false
      assert Repo.aggregate(Settings.UserSetting, :count) == 1
    end

    test "raises on an unknown key" do
      user = user_fixture()

      assert_raise NimbleOptions.ValidationError, fn ->
        Settings.User.put(user, :nonexistent, true)
      end
    end

    test "raises on a wrongly-typed value" do
      user = user_fixture()

      assert_raise NimbleOptions.ValidationError, fn ->
        Settings.User.put(user, :login_disabled, "yes")
      end
    end
  end

  describe "delete/2" do
    test "restores the default" do
      user = user_fixture()
      {:ok, _} = Settings.User.put(user, :login_disabled, true)

      :ok = Settings.User.delete(user, :login_disabled)

      assert Settings.User.fetch(user, :login_disabled) == false
    end
  end

  describe "key!/1" do
    test "casts a known key" do
      assert Settings.User.key!("login_disabled") == :login_disabled
    end

    test "raises on an unknown key" do
      assert_raise ArgumentError, fn -> Settings.User.key!("wat") end
    end
  end
end
