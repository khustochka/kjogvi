defmodule KjogviWeb.Live.My.Settings.PreferencesTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures

  alias Kjogvi.Factory
  alias Kjogvi.Repo

  defp observe_in(user, location) do
    {taxon, _} = Factory.create_species_taxon_with_page()
    checklist = insert(:checklist, user: user, location: location)
    insert(:observation, checklist: checklist, taxon_key: Ornitho.Schema.Taxon.key(taxon))
    :ok
  end

  describe "Preferences page" do
    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/my/settings/preferences")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/account/login"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  describe "default taxonomy" do
    test "user can select default book and it is saved", %{conn: conn} do
      book = Ornitho.Factory.insert(:book)

      user = user_fixture()

      {:ok, lv, _html} = conn |> login_user(user) |> live(~p"/my/settings/preferences")

      lv
      |> form("#settings_form", %{
        "user" => %{
          "default_book_signature" => "#{book.slug}/#{book.version}"
        }
      })
      |> render_submit()

      user = Repo.get!(Kjogvi.Accounts.User, user.id)
      assert user.default_book_signature == "#{book.slug}/#{book.version}"
    end
  end

  describe "logbook settings" do
    test "preferences page renders logbook settings section", %{conn: conn} do
      user = user_fixture()

      {:ok, _lv, html} = conn |> login_user(user) |> live(~p"/my/settings/preferences")

      assert html =~ "Logbook settings"
      assert html =~ "World"
      assert html =~ "Life"
      assert html =~ "Year"
    end

    test "only offers countries/subdivisions the user has observations in", %{conn: conn} do
      user = user_fixture()

      seen_country = insert(:country, name_en: "Canada")

      seen_region =
        insert(:location,
          location_type: "subdivision1",
          name_en: "Manitoba",
          country: seen_country
        )

      winnipeg =
        insert(:location,
          location_type: "city",
          country: seen_country,
          subdivision1_id: seen_region.id
        )

      observe_in(user, winnipeg)

      # A country with no observations from this user.
      insert(:country, name_en: "Poland")

      {:ok, _lv, html} = conn |> login_user(user) |> live(~p"/my/settings/preferences")

      assert html =~ "Canada"
      assert html =~ "Manitoba"
      refute html =~ "Poland"
    end

    test "another user's observations don't widen the offered locations", %{conn: conn} do
      user = user_fixture()
      other = user_fixture()

      poland = insert(:country, name_en: "Poland")
      observe_in(other, poland)

      {:ok, _lv, html} = conn |> login_user(user) |> live(~p"/my/settings/preferences")

      refute html =~ "Poland"
    end

    test "re-adds a saved location only when it has an enabled setting", %{conn: conn} do
      user = user_fixture()

      enabled = insert(:country, name_en: "Ukraine")
      disabled = insert(:country, name_en: "Poland")

      {:ok, user} =
        Kjogvi.Accounts.update_user_settings(user, %{
          "extras" => %{
            "logbook_settings" => %{
              "0" => %{"location_id" => "#{enabled.id}", "life" => "true", "year" => "false"},
              "1" => %{"location_id" => "#{disabled.id}", "life" => "false", "year" => "false"}
            }
          }
        })

      {:ok, _lv, html} = conn |> login_user(user) |> live(~p"/my/settings/preferences")

      # Enabled-but-no-observations location is kept; all-false leftover is dropped.
      assert html =~ "Ukraine"
      refute html =~ "Poland"
    end

    test "saving logbook settings persists them", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} = conn |> login_user(user) |> live(~p"/my/settings/preferences")

      lv
      |> form("#settings_form", %{
        "user" => %{
          "extras" => %{
            "logbook_settings" => %{
              "0" => %{"location_id" => "", "life" => "true", "year" => "false"}
            }
          }
        }
      })
      |> render_submit()

      user = Repo.get!(Kjogvi.Accounts.User, user.id)
      assert length(user.extras.logbook_settings) == 1

      setting = hd(user.extras.logbook_settings)
      assert setting.location_id == nil
      assert setting.life == true
      assert setting.year == false
    end
  end
end
