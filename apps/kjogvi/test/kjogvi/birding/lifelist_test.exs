defmodule Kjogvi.Birding.LifelistTest do
  alias Kjogvi.Factory
  alias Kjogvi.Birding.Lifelist
  use Kjogvi.DataCase, async: true

  import Kjogvi.UsersFixtures

  describe "years/1" do
    test "returns years that have cards and observation" do
      user = user_fixture()
      scope = %Lifelist.Scope{user: user, include_private: false}
      {taxon, _} = Factory.create_species_taxon_with_page()
      card1 = insert(:card, observ_date: ~D"2022-11-18", user: user)
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon))
      card2 = insert(:card, observ_date: ~D"2023-07-16", user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon))
      assert Kjogvi.Birding.Lifelist.years(scope) == [2022, 2023]
    end

    test "returns years in correct order" do
      user = user_fixture()
      scope = %Lifelist.Scope{user: user, include_private: false}
      {taxon, _} = Factory.create_species_taxon_with_page()
      card1 = insert(:card, observ_date: ~D"2023-11-18", user: user)
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon))
      card2 = insert(:card, observ_date: ~D"2022-07-16", user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon))
      assert Kjogvi.Birding.Lifelist.years(scope) == [2022, 2023]
    end

    test "does not include years with unreported observations only" do
      user = user_fixture()
      scope = %Lifelist.Scope{user: user, include_private: false}
      {taxon, _} = Factory.create_species_taxon_with_page()
      card1 = insert(:card, observ_date: ~D"2023-11-18", user: user)

      insert(:observation,
        card: card1,
        taxon_key: Ornitho.Schema.Taxon.key(taxon),
        unreported: true
      )

      card2 = insert(:card, observ_date: ~D"2022-07-16", user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon))
      assert Kjogvi.Birding.Lifelist.years(scope) == [2022]
    end
  end

  describe "months/1" do
    test "returns months that have cards and observation" do
      user = user_fixture()
      scope = %Lifelist.Scope{user: user, include_private: false}
      {taxon, _} = Factory.create_species_taxon_with_page()
      card1 = insert(:card, observ_date: ~D"2022-11-18", user: user)
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon))
      card2 = insert(:card, observ_date: ~D"2023-07-16", user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon))
      assert Kjogvi.Birding.Lifelist.months(scope) == [7, 11]
    end

    test "returns months in correct order" do
      user = user_fixture()
      scope = %Lifelist.Scope{user: user, include_private: false}
      {taxon, _} = Factory.create_species_taxon_with_page()
      card1 = insert(:card, observ_date: ~D"2023-11-18", user: user)
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon))
      card2 = insert(:card, observ_date: ~D"2022-07-16", user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon))
      assert Kjogvi.Birding.Lifelist.months(scope) == [7, 11]
    end

    test "does not include years with unreported observations only" do
      user = user_fixture()
      scope = %Lifelist.Scope{user: user, include_private: false}
      {taxon, _} = Factory.create_species_taxon_with_page()
      card1 = insert(:card, observ_date: ~D"2023-11-18", user: user)

      insert(:observation,
        card: card1,
        taxon_key: Ornitho.Schema.Taxon.key(taxon),
        unreported: true
      )

      card2 = insert(:card, observ_date: ~D"2022-07-16", user: user)

      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon))
      assert Kjogvi.Birding.Lifelist.months(scope) == [7]
    end
  end

  describe "generate/1" do
    test "works with no observations of the desired user" do
      user = user_fixture()
      scope = %Lifelist.Scope{user: user, include_private: false}
      taxon = Ornitho.Factory.insert(:taxon, category: "species")
      insert(:observation, taxon_key: Ornitho.Schema.Taxon.key(taxon))

      result = Kjogvi.Birding.Lifelist.generate(scope)
      assert result.list == []
    end

    test "includes species observation" do
      {taxon, _} = Factory.create_species_taxon_with_page()
      obs = insert(:observation, taxon_key: Ornitho.Schema.Taxon.key(taxon))
      scope = %Lifelist.Scope{user: obs.card.user, include_private: false}

      result = Kjogvi.Birding.Lifelist.generate(scope)

      assert length(result.list) == 1
      assert hd(result.list).species_page.name_sci == taxon.name_sci
    end

    test "includes subspecies observation" do
      {%{parent_species: species} = taxon, _} = Factory.create_subspecies_taxon_with_page()

      obs = insert(:observation, taxon_key: Ornitho.Schema.Taxon.key(taxon))

      scope = %Lifelist.Scope{user: obs.card.user, include_private: false}

      result = Kjogvi.Birding.Lifelist.generate(scope)

      assert length(result.list) == 1
      assert hd(result.list).species_page.name_sci == species.name_sci
    end

    test "uses subspecies observation date if it is earlier than the full species" do
      user = user_fixture()
      scope = %Lifelist.Scope{user: user, include_private: false}
      {%{parent_species: species} = subspecies, _} = Factory.create_subspecies_taxon_with_page()

      card1 = insert(:card, observ_date: ~D[2022-06-11], user: user)

      insert(:observation,
        card: card1,
        taxon_key: Ornitho.Schema.Taxon.key(subspecies)
      )

      card2 = insert(:card, observ_date: ~D[2023-08-19], user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(species))

      result = Kjogvi.Birding.Lifelist.generate(scope)
      assert length(result.list)
      assert hd(result.list).observ_date == card1.observ_date
    end

    test "does not include spuh observation" do
      taxon = Ornitho.Factory.insert(:taxon, category: "spuh")

      obs =
        insert(:observation, taxon_key: Ornitho.Schema.Taxon.key(taxon))

      scope = %Lifelist.Scope{user: obs.card.user, include_private: false}

      result = Kjogvi.Birding.Lifelist.generate(scope)
      assert result.list == []
    end

    test "does not include observation with unknown taxon key" do
      obs =
        insert(:observation, taxon_key: "/abc/v1/taxon")

      scope = %Lifelist.Scope{user: obs.card.user, include_private: false}

      result = Kjogvi.Birding.Lifelist.generate(scope)
      assert result.list == []
    end

    test "filtered by year" do
      user = user_fixture()
      scope = %Lifelist.Scope{user: user, include_private: false}
      {taxon1, _} = Factory.create_species_taxon_with_page()
      card1 = insert(:card, observ_date: ~D"2022-11-18", user: user)
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon1))
      {taxon2, _} = Factory.create_species_taxon_with_page()
      card2 = insert(:card, observ_date: ~D"2023-07-16", user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon2))

      result = Kjogvi.Birding.Lifelist.generate(scope, year: 2022)
      assert length(result.list) == 1
    end

    test "filtered by missing year" do
      user = user_fixture()
      scope = %Lifelist.Scope{user: user, include_private: false}
      {taxon1, _} = Factory.create_species_taxon_with_page()
      card1 = insert(:card, observ_date: ~D"2022-11-18", user: user)
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon1))
      {taxon2, _} = Factory.create_species_taxon_with_page()
      card2 = insert(:card, observ_date: ~D"2023-07-16", user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon2))

      result = Kjogvi.Birding.Lifelist.generate(scope, year: 2005)
      assert result.list == []
    end

    test "filtered by country" do
      user = user_fixture()
      scope = %Lifelist.Scope{user: user, include_private: false}
      ukraine = insert(:location, slug: "ukraine", name_en: "Ukraine", location_type: "country")
      usa = insert(:location, slug: "usa", name_en: "United States", location_type: "country")
      brovary = insert(:location, slug: "brovary", name_en: "Brovary", ancestry: [ukraine.id])

      {taxon1, _} = Factory.create_species_taxon_with_page()
      card1 = insert(:card, location: brovary, user: user)
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon1))
      {taxon2, _} = Factory.create_species_taxon_with_page()
      card2 = insert(:card, location: usa, user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon2))

      result = Kjogvi.Birding.Lifelist.generate(scope, location: ukraine)
      assert length(result.list) == 1
    end

    test "filtered by location" do
      user = user_fixture()
      scope = %Lifelist.Scope{user: user, include_private: false}
      ukraine = insert(:location, slug: "ukraine", name_en: "Ukraine", location_type: "country")
      usa = insert(:location, slug: "usa", name_en: "United States", location_type: "country")
      brovary = insert(:location, slug: "brovary", name_en: "Brovary", ancestry: [ukraine.id])

      {taxon1, _} = Factory.create_species_taxon_with_page()
      card1 = insert(:card, location: brovary, user: user)
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon1))
      {taxon2, _} = Factory.create_species_taxon_with_page()
      card2 = insert(:card, location: usa, user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon2))

      result = Kjogvi.Birding.Lifelist.generate(scope, location: brovary)
      assert length(result.list) == 1
    end

    test "filtered by year and country" do
      user = user_fixture()
      scope = %Lifelist.Scope{user: user, include_private: false}
      ukraine = insert(:location, slug: "ukraine", name_en: "Ukraine", location_type: "country")
      usa = insert(:location, slug: "usa", name_en: "United States", location_type: "country")
      brovary = insert(:location, slug: "brovary", name_en: "Brovary", ancestry: [ukraine.id])

      {taxon1, _} = Factory.create_species_taxon_with_page()
      card1 = insert(:card, observ_date: ~D"2022-11-18", location: brovary, user: user)
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon1))
      {taxon2, _} = Factory.create_species_taxon_with_page()
      card2 = insert(:card, observ_date: ~D"2023-07-16", location: brovary, user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon2))
      {taxon3, _} = Factory.create_species_taxon_with_page()
      card2 = insert(:card, observ_date: ~D"2022-07-16", location: usa, user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon3))

      result = Kjogvi.Birding.Lifelist.generate(scope, location: ukraine, year: 2022)
      assert length(result.list) == 1
    end

    test "filtered by month" do
      user = user_fixture()
      scope = %Lifelist.Scope{user: user, include_private: false}
      {taxon1, _} = Factory.create_species_taxon_with_page()
      card1 = insert(:card, observ_date: ~D"2022-11-18", user: user)
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon1))
      {taxon2, _} = Factory.create_species_taxon_with_page()
      card2 = insert(:card, observ_date: ~D"2023-07-16", user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon2))

      result = Kjogvi.Birding.Lifelist.generate(scope, month: 7)
      assert length(result.list) == 1
    end

    test "filtered by motorless" do
      user = user_fixture()
      scope = %Lifelist.Scope{user: user, include_private: false}
      {taxon1, _} = Factory.create_species_taxon_with_page()
      card1 = insert(:card, observ_date: ~D"2022-11-18", user: user, motorless: true)
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon1))
      {taxon2, _} = Factory.create_species_taxon_with_page()
      card2 = insert(:card, observ_date: ~D"2023-07-16", user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon2))

      result = Kjogvi.Birding.Lifelist.generate(scope, motorless: true)
      assert length(result.list) == 1
    end

    test "filtered by special location" do
      user = user_fixture()
      scope = %Lifelist.Scope{user: user, include_private: false}
      locus1 = insert(:location, slug: "bunns_creek", name_en: "Bunn's Creek")
      locus2 = insert(:location, slug: "kildonan_park", name_en: "Kildonan Park")

      locus3 =
        insert(:location, slug: "witches_hut", name_en: "Witch's Hut", ancestry: [locus2.id])

      locus4 = insert(:location, slug: "assiniboine_park", name_en: "Assiniboine Park")

      locus_5mr =
        insert(:location,
          slug: "5mr",
          name_en: "5MR",
          location_type: "special",
          special_child_locations: [locus1, locus2]
        )

      {taxon1, _} = Factory.create_species_taxon_with_page()
      card1 = insert(:card, observ_date: ~D"2022-11-18", location: locus1, user: user)
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon1))

      # Locus 3 is a child of locus 2, so it should be included
      {taxon2, _} = Factory.create_species_taxon_with_page()
      card2 = insert(:card, observ_date: ~D"2023-07-16", location: locus3, user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon2))

      {taxon3, _} = Factory.create_species_taxon_with_page()
      card2 = insert(:card, observ_date: ~D"2022-07-16", location: locus4, user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon3))

      result = Kjogvi.Birding.Lifelist.generate(scope, location: locus_5mr)
      assert length(result.list) == 2
    end

    test "exclude heard only has the species at the later date" do
      user = user_fixture()
      scope = %Lifelist.Scope{user: user, include_private: false}
      locus = insert(:location)

      {taxon1, _} = Factory.create_species_taxon_with_page()
      card0 = insert(:card, observ_date: ~D"2022-11-18", location: locus, user: user)
      insert(:observation, card: card0, voice: true, taxon_key: Ornitho.Schema.Taxon.key(taxon1))

      card1 = insert(:card, observ_date: ~D"2023-12-19", location: locus, user: user)
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon1))

      {taxon2, _} = Factory.create_species_taxon_with_page()
      card2 = insert(:card, observ_date: ~D"2024-12-31", location: locus, user: user)
      insert(:observation, card: card2, voice: true, taxon_key: Ornitho.Schema.Taxon.key(taxon2))

      {taxon3, _} = Factory.create_species_taxon_with_page()
      card3 = insert(:card, observ_date: ~D"2024-12-31", location: locus, user: user)
      insert(:observation, card: card3, taxon_key: Ornitho.Schema.Taxon.key(taxon3))

      result = Kjogvi.Birding.Lifelist.generate(scope, exclude_heard_only: true)
      assert length(result.list) == 2

      assert Enum.map(result.list, & &1.species_page.name_sci) == [
               taxon3.name_sci,
               taxon1.name_sci
             ]

      assert Enum.map(result.list, & &1.observ_date) == [card3.observ_date, card1.observ_date]
    end

    test "unreported observations not included in private view" do
      user = user_fixture()
      scope = %Lifelist.Scope{user: user, include_private: false}

      {taxon1, _} = Factory.create_species_taxon_with_page()
      {taxon2, _} = Factory.create_species_taxon_with_page()
      card1 = insert(:card, observ_date: ~D"2023-11-18", user: user)

      insert(:observation,
        card: card1,
        taxon_key: Ornitho.Schema.Taxon.key(taxon1),
        unreported: true
      )

      insert(:observation,
        card: card1,
        taxon_key: Ornitho.Schema.Taxon.key(taxon2)
      )

      result = Kjogvi.Birding.Lifelist.generate(scope)

      assert length(result.list) == 1

      assert Enum.map(result.list, & &1.species_page.name_sci) == [taxon2.name_sci]
    end

    test "hidden observations are included in private view" do
      user = user_fixture()
      scope = %Lifelist.Scope{user: user, include_private: true}

      {taxon1, _} = Factory.create_species_taxon_with_page()
      {taxon2, _} = Factory.create_species_taxon_with_page()
      card1 = insert(:card, observ_date: ~D"2023-11-18", user: user)

      insert(:observation,
        card: card1,
        taxon_key: Ornitho.Schema.Taxon.key(taxon1),
        hidden: true
      )

      insert(:observation,
        card: card1,
        taxon_key: Ornitho.Schema.Taxon.key(taxon2)
      )

      result = Kjogvi.Birding.Lifelist.generate(scope)

      assert length(result.list) == 2

      name_scis = Enum.map(result.list, & &1.species_page.name_sci)
      assert taxon1.name_sci in name_scis
      assert taxon2.name_sci in name_scis
    end

    test "hidden observations are not included in public view" do
      user = user_fixture()
      scope = %Lifelist.Scope{user: user, include_private: false}

      {taxon1, _} = Factory.create_species_taxon_with_page()
      {taxon2, _} = Factory.create_species_taxon_with_page()
      card1 = insert(:card, observ_date: ~D"2023-11-18", user: user)

      insert(:observation,
        card: card1,
        taxon_key: Ornitho.Schema.Taxon.key(taxon1),
        hidden: true
      )

      insert(:observation,
        card: card1,
        taxon_key: Ornitho.Schema.Taxon.key(taxon2)
      )

      result = Kjogvi.Birding.Lifelist.generate(scope)

      assert length(result.list) == 1

      assert Enum.map(result.list, & &1.species_page.name_sci) == [taxon2.name_sci]
    end

    test "works with private locations" do
      public_loc = insert(:location)

      private_loc =
        insert(:location,
          is_private: true,
          ancestry: [public_loc.id],
          cached_public_location: public_loc
        )

      user = user_fixture()
      card = insert(:card, user: user, location: private_loc)

      {taxon, _} = Factory.create_species_taxon_with_page()
      insert(:observation, card: card, taxon_key: Ornitho.Schema.Taxon.key(taxon))

      scope = %Lifelist.Scope{user: user, include_private: false}

      result = Kjogvi.Birding.Lifelist.generate(scope)

      assert length(result.list) == 1
    end

    test "with heard only separated" do
      user = user_fixture()

      {taxon1, _} = Factory.create_species_taxon_with_page()
      {taxon2, _} = Factory.create_species_taxon_with_page()
      card1 = insert(:card, observ_date: ~D"2023-11-18", user: user)

      insert(:observation,
        card: card1,
        taxon_key: Ornitho.Schema.Taxon.key(taxon1),
        voice: true
      )

      insert(:observation,
        card: card1,
        taxon_key: Ornitho.Schema.Taxon.key(taxon2)
      )

      scope = %Lifelist.Scope{user: user}
      result = Kjogvi.Birding.Lifelist.generate(scope, exclude_heard_only: true)

      assert length(result.list) == 1
      assert length(result.extras.heard_only.list) == 1
    end
  end
end
