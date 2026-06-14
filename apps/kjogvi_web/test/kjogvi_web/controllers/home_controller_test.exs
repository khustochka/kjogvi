defmodule KjogviWeb.HomeControllerTest do
  use KjogviWeb.ConnCase, async: true

  import Kjogvi.AccountsFixtures

  defp observe_species(user, taxon) do
    card = insert(:card, user: user)
    insert(:observation, card: card, taxon_key: Ornitho.Schema.Taxon.key(taxon))
  end

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Kjogvi"
  end

  test "lists birders ordered by public life list size with species counts", %{conn: conn} do
    {taxon1, _} = create_species_taxon_with_page()
    {taxon2, _} = create_species_taxon_with_page()

    leader = user_fixture(nickname: "leader")
    observe_species(leader, taxon1)
    observe_species(leader, taxon2)

    runner_up = user_fixture(nickname: "runnerup")
    observe_species(runner_up, taxon1)

    html = conn |> get(~p"/") |> html_response(200)

    assert html =~ "2 species"
    assert html =~ "1 species"
    # The leader (2 species) is rendered before the runner-up (1 species).
    assert :binary.match(html, "leader") |> elem(0) <
             (:binary.match(html, "runnerup") |> elem(0))
  end

  test "omits users with no public species", %{conn: conn} do
    user_fixture(nickname: "nolist")

    html = conn |> get(~p"/") |> html_response(200)

    refute html =~ "nolist"
  end
end
