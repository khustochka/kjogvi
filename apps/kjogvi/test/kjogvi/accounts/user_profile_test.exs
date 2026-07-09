defmodule Kjogvi.Accounts.UserProfileTest do
  use Kjogvi.DataCase, async: true

  import Kjogvi.AccountsFixtures

  alias Kjogvi.Accounts
  alias Kjogvi.Accounts.UserProfile

  describe "changeset/2" do
    test "casts all fields" do
      changeset =
        UserProfile.changeset(%UserProfile{}, %{
          "about" => "Birder since forever.",
          "country" => "US",
          "ebird_profile_url" => "https://ebird.org/profile/abc",
          "website_url" => "https://example.com",
          "birding_since" => "2005"
        })

      assert changeset.valid?
      profile = Ecto.Changeset.apply_changes(changeset)
      assert profile.about == "Birder since forever."
      assert profile.country == "US"
      assert profile.ebird_profile_url == "https://ebird.org/profile/abc"
      assert profile.website_url == "https://example.com"
      assert profile.birding_since == 2005
    end

    test "accepts a blank changeset" do
      assert UserProfile.changeset(%UserProfile{}, %{}).valid?
    end

    test "rejects an over-long about" do
      changeset =
        UserProfile.changeset(%UserProfile{}, %{"about" => String.duplicate("a", 2001)})

      refute changeset.valid?
      assert %{about: [_]} = errors_on(changeset)
    end

    test "rejects a non-ISO country code" do
      for bad <- ["USA", "us", "U1", "United States"] do
        changeset = UserProfile.changeset(%UserProfile{}, %{"country" => bad})
        refute changeset.valid?, "expected #{inspect(bad)} to be rejected"
        assert %{country: [_]} = errors_on(changeset)
      end
    end

    test "rejects non-http(s) URLs" do
      for field <- [:ebird_profile_url, :website_url] do
        changeset = UserProfile.changeset(%UserProfile{}, %{to_string(field) => "ftp://x.test"})
        refute changeset.valid?
        assert Map.has_key?(errors_on(changeset), field)
      end
    end

    test "rejects a URL with no host" do
      changeset = UserProfile.changeset(%UserProfile{}, %{"website_url" => "https://"})
      refute changeset.valid?
      assert %{website_url: [_]} = errors_on(changeset)
    end

    test "rejects a birding_since before 1900" do
      changeset = UserProfile.changeset(%UserProfile{}, %{"birding_since" => "1899"})
      refute changeset.valid?
      assert %{birding_since: [_]} = errors_on(changeset)
    end

    test "rejects a birding_since in the future" do
      next_year = Date.utc_today().year + 1
      changeset = UserProfile.changeset(%UserProfile{}, %{"birding_since" => "#{next_year}"})
      refute changeset.valid?
      assert %{birding_since: [_]} = errors_on(changeset)
    end
  end

  describe "Accounts.update_user_profile_settings/2" do
    test "creates the profile row lazily on first save" do
      user = user_fixture()
      refute Repo.get_by(UserProfile, user_id: user.id)

      {:ok, updated} =
        Accounts.update_user_profile_settings(user, %{
          "profile" => %{"country" => "US", "birding_since" => "2010"}
        })

      assert updated.nickname == user.nickname

      assert %UserProfile{country: "US", birding_since: 2010} =
               Repo.get_by(UserProfile, user_id: user.id)
    end

    test "updates an existing profile row" do
      user = user_fixture()

      {:ok, _} =
        Accounts.update_user_profile_settings(user, %{
          "profile" => %{"country" => "US"}
        })

      {:ok, _} =
        Accounts.update_user_profile_settings(user, %{
          "profile" => %{"website_url" => "https://example.com"}
        })

      profile = Repo.get_by(UserProfile, user_id: user.id)
      assert profile.country == "US"
      assert profile.website_url == "https://example.com"
    end

    test "returns an error changeset for invalid profile data" do
      user = user_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Accounts.update_user_profile_settings(user, %{
                 "profile" => %{"country" => "USA"}
               })

      refute Repo.get_by(UserProfile, user_id: user.id)
    end
  end
end
