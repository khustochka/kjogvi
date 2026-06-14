defmodule KjogviWeb.Live.My.Logbook.IndexTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures

  alias Kjogvi.Factory
  alias Kjogvi.GeoFixtures

  setup %{conn: conn} do
    user = user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  test "renders the logbook page", %{conn: conn} do
    conn = get(conn, ~p"/my/logbook")
    assert html_response(conn, 200) =~ "Birding logbook"
  end

  test "always shows a link to logbook settings", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/my/logbook")

    assert lv
           |> element("a[href='/my/account/settings#logbook-settings']", "Logbook settings")
           |> has_element?()
  end

  test "when no lists are enabled and logbook is empty, shows enable-lists callout", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/my/logbook")

    assert has_element?(lv, "#logbook-empty-no-settings")
  end

  test "when at least one list is enabled, the enable-lists callout is hidden", %{user: user} do
    {:ok, _user} =
      Kjogvi.Accounts.update_user_settings(user, %{
        "extras" => %{
          "logbook_settings" => %{
            "0" => %{"location_id" => "", "life" => "true", "year" => "false"}
          }
        }
      })

    # Re-login the (unchanged) user to pick up updated extras in scope.
    conn = log_in_user(build_conn(), Kjogvi.Repo.get!(Kjogvi.Accounts.User, user.id))

    {:ok, lv, _html} = live(conn, ~p"/my/logbook")

    refute has_element?(lv, "#logbook-empty-no-settings")
  end

  test "list_total links to the correct lifelist anchor", %{conn: conn, user: user} do
    country =
      GeoFixtures.location_fixture(%{
        name_en: "Canada",
        location_type: "country",
        ancestry: [],
        public_index: 1
      })

    site =
      GeoFixtures.location_fixture(%{
        name_en: "Some Site",
        location_type: "site",
        ancestry: [country.id]
      })

    {taxon, _} = Factory.create_species_taxon_with_page()
    card = insert(:card, observ_date: Date.utc_today(), user: user, location: site)
    insert(:observation, card: card, taxon_key: Ornitho.Schema.Taxon.key(taxon))

    conn = get(conn, ~p"/my/logbook")
    html = html_response(conn, 200)

    {:ok, doc} = Floki.parse_document(html)

    # The (1) total should be a link ending with #lifer-1
    links = doc |> Floki.find("a") |> Enum.flat_map(&Floki.attribute(&1, "href"))
    assert Enum.any?(links, &String.ends_with?(&1, "#lifer-1"))
  end
end
