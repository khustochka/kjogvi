defmodule Kjogvi.Birding.CardSearchTest do
  use Kjogvi.DataCase, async: true

  import Kjogvi.AccountsFixtures

  alias Kjogvi.Birding
  alias Kjogvi.Birding.CardSearch.Filter

  defp species_key do
    {taxon, _page} = Kjogvi.Factory.create_species_taxon_with_page()
    Ornitho.Schema.Taxon.key(taxon)
  end

  defp page(user, filter) do
    Birding.search_cards(user, filter, %{page: 1, page_size: 50})
  end

  describe "search_cards/3 — card mode" do
    test "returns all cards when filter is blank, with observations left unloaded" do
      user = user_fixture()
      card = insert(:card, user: user)
      insert(:observation, card: card, taxon_key: species_key())
      insert(:observation, card: card, taxon_key: "ebird/eBird_2023/amecro")

      result = page(user, %Filter{})

      assert [entry] = result.entries
      assert entry.id == card.id
      # Card mode does not attach observations to the panels.
      assert %Ecto.Association.NotLoaded{} = entry.observations
    end

    test "filters by exact date" do
      user = user_fixture()
      match = insert(:card, user: user, observ_date: ~D[2024-05-01])
      insert(:card, user: user, observ_date: ~D[2024-05-02])

      result = page(user, %Filter{date: ~D[2024-05-01]})

      assert [entry] = result.entries
      assert entry.id == match.id
    end

    test "filters by location (exact, no subregions)" do
      user = user_fixture()
      loc = insert(:location)
      other = insert(:location)
      match = insert(:card, user: user, location: loc)
      insert(:card, user: user, location: other)

      result = page(user, %Filter{location: loc})

      assert [entry] = result.entries
      assert entry.id == match.id
    end

    test "with include_subregions, matches cards in descendant locations" do
      user = user_fixture()
      parent = insert(:location)
      child = insert(:location, ancestry: [parent.id])

      parent_card = insert(:card, user: user, location: parent)
      child_card = insert(:card, user: user, location: child)

      ids =
        page(user, %Filter{location: parent, include_subregions: true})
        |> Map.fetch!(:entries)
        |> Enum.map(& &1.id)
        |> Enum.sort()

      assert ids == Enum.sort([parent_card.id, child_card.id])
    end
  end

  describe "search_cards/3 — observation mode" do
    test "returns only cards that have a matching observation" do
      user = user_fixture()
      key = species_key()

      with_match = insert(:card, user: user)
      insert(:observation, card: with_match, taxon_key: key)

      without_match = insert(:card, user: user)
      insert(:observation, card: without_match, taxon_key: "ebird/eBird_2023/amecro")

      result = page(user, %Filter{taxon_key: key, exclude_subspecies: true})

      assert [entry] = result.entries
      assert entry.id == with_match.id
    end

    test "attaches only the matching observations to each card" do
      user = user_fixture()
      key = species_key()

      card = insert(:card, user: user)
      match = insert(:observation, card: card, taxon_key: key)
      insert(:observation, card: card, taxon_key: "ebird/eBird_2023/amecro")

      result = page(user, %Filter{taxon_key: key, exclude_subspecies: true})

      assert [entry] = result.entries
      assert [obs] = entry.observations
      assert obs.id == match.id
    end

    test "voice :heard_only keeps only heard observations" do
      user = user_fixture()
      card = insert(:card, user: user)
      heard = insert(:observation, card: card, taxon_key: species_key(), voice: true)
      insert(:observation, card: card, taxon_key: "ebird/eBird_2023/amecro", voice: false)

      result = page(user, %Filter{voice: :heard_only})

      assert [entry] = result.entries
      assert [obs] = entry.observations
      assert obs.id == heard.id
    end

    test "voice :seen keeps only non-heard observations" do
      user = user_fixture()
      card = insert(:card, user: user)
      insert(:observation, card: card, taxon_key: species_key(), voice: true)
      seen = insert(:observation, card: card, taxon_key: "ebird/eBird_2023/amecro", voice: false)

      result = page(user, %Filter{voice: :seen})

      assert [entry] = result.entries
      assert [obs] = entry.observations
      assert obs.id == seen.id
    end

    test "hidden keeps only hidden observations" do
      user = user_fixture()
      card = insert(:card, user: user)
      hidden = insert(:observation, card: card, taxon_key: species_key(), hidden: true)
      insert(:observation, card: card, taxon_key: "ebird/eBird_2023/amecro", hidden: false)

      result = page(user, %Filter{hidden: true})

      assert [entry] = result.entries
      assert [obs] = entry.observations
      assert obs.id == hidden.id
    end

    test "does not return cards from other users" do
      user = user_fixture()
      other = user_fixture()
      other_card = insert(:card, user: other)
      insert(:observation, card: other_card, taxon_key: species_key(), hidden: true)

      assert page(user, %Filter{hidden: true}).entries == []
    end
  end
end
