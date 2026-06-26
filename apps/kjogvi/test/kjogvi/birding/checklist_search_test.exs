defmodule Kjogvi.Birding.ChecklistSearchTest do
  use Kjogvi.DataCase, async: true

  import Kjogvi.AccountsFixtures

  alias Kjogvi.Birding
  alias Kjogvi.Birding.ChecklistSearch.Filter

  defp species_key do
    {taxon, _page} = Kjogvi.Factory.create_species_taxon_with_page()
    Ornitho.Schema.Taxon.key(taxon)
  end

  defp page(user, filter) do
    Birding.search_cards(user, filter, %{page: 1, page_size: 50})
  end

  describe "search_cards/3 — checklist mode" do
    test "returns all cards when filter is blank, with observations left unloaded" do
      user = user_fixture()
      checklist = insert(:checklist, user: user)
      insert(:observation, checklist: checklist, taxon_key: species_key())
      insert(:observation, checklist: checklist, taxon_key: "ebird/eBird_2023/amecro")

      result = page(user, %Filter{})

      assert [entry] = result.entries
      assert entry.id == checklist.id
      # Checklist mode does not attach observations to the panels.
      assert %Ecto.Association.NotLoaded{} = entry.observations
    end

    test "filters by exact date" do
      user = user_fixture()
      match = insert(:checklist, user: user, observ_date: ~D[2024-05-01])
      insert(:checklist, user: user, observ_date: ~D[2024-05-02])

      result = page(user, %Filter{date: ~D[2024-05-01]})

      assert [entry] = result.entries
      assert entry.id == match.id
    end

    test "filters by location (exact, no subregions)" do
      user = user_fixture()
      loc = insert(:location)
      other = insert(:location)
      match = insert(:checklist, user: user, location: loc)
      insert(:checklist, user: user, location: other)

      result = page(user, %Filter{location: loc})

      assert [entry] = result.entries
      assert entry.id == match.id
    end

    test "with include_subregions, matches cards in descendant locations" do
      user = user_fixture()
      parent = insert(:country)
      child = insert(:location, location_type: "city", country: parent)

      parent_card = insert(:checklist, user: user, location: parent)
      child_card = insert(:checklist, user: user, location: child)

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

      with_match = insert(:checklist, user: user)
      insert(:observation, checklist: with_match, taxon_key: key)

      without_match = insert(:checklist, user: user)
      insert(:observation, checklist: without_match, taxon_key: "ebird/eBird_2023/amecro")

      result = page(user, %Filter{taxon_key: key, exclude_subspecies: true})

      assert [entry] = result.entries
      assert entry.id == with_match.id
    end

    test "attaches only the matching observations to each checklist" do
      user = user_fixture()
      key = species_key()

      checklist = insert(:checklist, user: user)
      match = insert(:observation, checklist: checklist, taxon_key: key)
      insert(:observation, checklist: checklist, taxon_key: "ebird/eBird_2023/amecro")

      result = page(user, %Filter{taxon_key: key, exclude_subspecies: true})

      assert [entry] = result.entries
      assert [obs] = entry.observations
      assert obs.id == match.id
    end

    test "voice :heard_only keeps only heard observations" do
      user = user_fixture()
      checklist = insert(:checklist, user: user)
      heard = insert(:observation, checklist: checklist, taxon_key: species_key(), voice: true)

      insert(:observation,
        checklist: checklist,
        taxon_key: "ebird/eBird_2023/amecro",
        voice: false
      )

      result = page(user, %Filter{voice: :heard_only})

      assert [entry] = result.entries
      assert [obs] = entry.observations
      assert obs.id == heard.id
    end

    test "voice :seen keeps only non-heard observations" do
      user = user_fixture()
      checklist = insert(:checklist, user: user)
      insert(:observation, checklist: checklist, taxon_key: species_key(), voice: true)

      seen =
        insert(:observation,
          checklist: checklist,
          taxon_key: "ebird/eBird_2023/amecro",
          voice: false
        )

      result = page(user, %Filter{voice: :seen})

      assert [entry] = result.entries
      assert [obs] = entry.observations
      assert obs.id == seen.id
    end

    test "hidden keeps only hidden observations" do
      user = user_fixture()
      checklist = insert(:checklist, user: user)
      hidden = insert(:observation, checklist: checklist, taxon_key: species_key(), hidden: true)

      insert(:observation,
        checklist: checklist,
        taxon_key: "ebird/eBird_2023/amecro",
        hidden: false
      )

      result = page(user, %Filter{hidden: true})

      assert [entry] = result.entries
      assert [obs] = entry.observations
      assert obs.id == hidden.id
    end

    test "does not return cards from other users" do
      user = user_fixture()
      other = user_fixture()
      other_card = insert(:checklist, user: other)
      insert(:observation, checklist: other_card, taxon_key: species_key(), hidden: true)

      assert page(user, %Filter{hidden: true}).entries == []
    end
  end
end
