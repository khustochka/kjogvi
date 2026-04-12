defmodule KjogviWeb.Live.My.Log.IndexTest do
  use KjogviWeb.ConnCase, async: true

  import Kjogvi.UsersFixtures

  alias Kjogvi.Factory
  alias Kjogvi.GeoFixtures

  setup %{conn: conn} do
    user = user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  test "renders the log page", %{conn: conn} do
    conn = get(conn, ~p"/my/log")
    assert html_response(conn, 200) =~ "Recent additions"
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

    conn = get(conn, ~p"/my/log")
    html = html_response(conn, 200)

    {:ok, doc} = Floki.parse_document(html)

    # The (1) total should be a link ending with #lifer-1
    links = doc |> Floki.find("a") |> Enum.flat_map(&Floki.attribute(&1, "href"))
    assert Enum.any?(links, &String.ends_with?(&1, "#lifer-1"))
  end
end
