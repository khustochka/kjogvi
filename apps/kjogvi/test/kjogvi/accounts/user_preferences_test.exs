defmodule Kjogvi.Accounts.UserPreferencesTest do
  use Kjogvi.DataCase, async: true

  import Kjogvi.AccountsFixtures

  alias Kjogvi.Accounts
  alias Kjogvi.Accounts.UserPreferences

  describe "changeset/2" do
    test "casts ebird credentials" do
      changeset =
        UserPreferences.changeset(%UserPreferences{}, %{
          "ebird" => %{"username" => "birder", "password" => "secret"}
        })

      assert changeset.valid?
      preferences = Ecto.Changeset.apply_changes(changeset)
      assert preferences.ebird.username == "birder"
      assert preferences.ebird.password == "secret"
    end

    test "casts logbook_settings" do
      changeset =
        UserPreferences.changeset(%UserPreferences{}, %{
          "logbook_settings" => %{
            "0" => %{"location_id" => "", "life" => "true", "year" => "false"},
            "1" => %{"location_id" => "42", "life" => "true", "year" => "true"}
          }
        })

      assert changeset.valid?
      settings = Ecto.Changeset.apply_changes(changeset).logbook_settings
      assert length(settings) == 2

      world = Enum.find(settings, &is_nil(&1.location_id))
      assert world.life == true
      assert world.year == false

      loc = Enum.find(settings, &(&1.location_id == 42))
      assert loc.life == true
      assert loc.year == true
    end

    test "preserves ebird credentials when only logbook_settings are provided" do
      preferences = %UserPreferences{ebird: %UserPreferences.Ebird{username: "birder"}}

      changeset =
        UserPreferences.changeset(preferences, %{
          "logbook_settings" => %{
            "0" => %{"location_id" => "", "life" => "true", "year" => "true"}
          }
        })

      assert changeset.valid?
      assert Ecto.Changeset.apply_changes(changeset).ebird.username == "birder"
    end
  end

  describe "ebird_configured_sync?/1" do
    test "true with username only" do
      assert UserPreferences.ebird_configured_sync?(%UserPreferences{
               ebird: %UserPreferences.Ebird{username: "birder"}
             })

      refute UserPreferences.ebird_configured_sync?(%UserPreferences{})
    end
  end

  describe "ebird_configured_async?/1" do
    test "requires both username and password" do
      assert UserPreferences.ebird_configured_async?(%UserPreferences{
               ebird: %UserPreferences.Ebird{username: "birder", password: "secret"}
             })

      refute UserPreferences.ebird_configured_async?(%UserPreferences{
               ebird: %UserPreferences.Ebird{username: "birder"}
             })

      refute UserPreferences.ebird_configured_async?(%UserPreferences{})
    end
  end

  describe "Accounts.update_user_preferences/2" do
    test "creates the preferences row lazily on first save" do
      user = user_fixture()
      refute Repo.get_by(UserPreferences, user_id: user.id)

      {:ok, updated} =
        Accounts.update_user_preferences(user, %{
          "default_book_signature" => "J. Doe",
          "preferences" => %{"ebird" => %{"username" => "birder"}}
        })

      assert updated.default_book_signature == "J. Doe"

      assert %UserPreferences{ebird: %{username: "birder"}} =
               Repo.get_by(UserPreferences, user_id: user.id)
    end

    test "updates an existing preferences row" do
      user = user_fixture()

      {:ok, _} =
        Accounts.update_user_preferences(user, %{
          "preferences" => %{"ebird" => %{"username" => "first"}}
        })

      {:ok, _} =
        Accounts.update_user_preferences(user, %{
          "preferences" => %{
            "ebird" => %{"password" => "secret"},
            "logbook_settings" => %{
              "0" => %{"location_id" => "", "life" => "false", "year" => "true"}
            }
          }
        })

      preferences = Repo.get_by(UserPreferences, user_id: user.id)
      assert preferences.ebird.username == "first"
      assert preferences.ebird.password == "secret"
      assert [%{location_id: nil, life: false, year: true}] = preferences.logbook_settings
    end
  end

  describe "Accounts.get_user_preferences/1" do
    test "returns a default struct when the user has no preferences row" do
      user = user_fixture()

      assert %UserPreferences{id: nil, logbook_settings: []} =
               Accounts.get_user_preferences(user)
    end

    test "returns the saved row" do
      user = user_fixture()

      {:ok, _} =
        Accounts.update_user_preferences(user, %{
          "preferences" => %{"ebird" => %{"username" => "birder"}}
        })

      assert %UserPreferences{ebird: %{username: "birder"}} = Accounts.get_user_preferences(user)
    end
  end
end
