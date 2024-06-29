defmodule Kjogvi.Birding.LifelistTest do
  use Kjogvi.DataCase, async: true

  import Kjogvi.UsersFixtures

  describe "years/1" do
    test "returns years that have cards and observation" do
      user = user_fixture()
      taxon = Ornitho.Factory.insert(:taxon)
      card1 = insert(:card, observ_date: ~D"2022-11-18", user: user)
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon))
      card2 = insert(:card, observ_date: ~D"2023-07-16", user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon))
      assert Kjogvi.Birding.Lifelist.years(user) == [2022, 2023]
    end

    test "returns years in correct order" do
      user = user_fixture()
      taxon = Ornitho.Factory.insert(:taxon)
      card1 = insert(:card, observ_date: ~D"2023-11-18", user: user)
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon))
      card2 = insert(:card, observ_date: ~D"2022-07-16", user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon))
      assert Kjogvi.Birding.Lifelist.years(user) == [2022, 2023]
    end

    test "does not include years with unreported observations only" do
      user = user_fixture()
      taxon = Ornitho.Factory.insert(:taxon)
      card1 = insert(:card, observ_date: ~D"2023-11-18", user: user)

      insert(:observation,
        card: card1,
        taxon_key: Ornitho.Schema.Taxon.key(taxon),
        unreported: true
      )

      card2 = insert(:card, observ_date: ~D"2022-07-16", user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon))
      assert Kjogvi.Birding.Lifelist.years(user) == [2022]
    end
  end

  describe "generate/1" do
    test "works with no observations of the desired user" do
      taxon = Ornitho.Factory.insert(:taxon, category: "species")
      insert(:observation, taxon_key: Ornitho.Schema.Taxon.key(taxon))

      result = Kjogvi.Birding.Lifelist.generate(user_fixture())
      assert result == []
    end

    test "includes species observation" do
      taxon = Ornitho.Factory.insert(:taxon, category: "species")
      obs = insert(:observation, taxon_key: Ornitho.Schema.Taxon.key(taxon))

      result = Kjogvi.Birding.Lifelist.generate(obs.card.user)
      assert hd(result).species.name_sci == taxon.name_sci
    end

    test "includes subspecies observation" do
      book = Ornitho.Factory.insert(:book)
      species = Ornitho.Factory.insert(:taxon, book: book, category: "species")

      taxon =
        Ornitho.Factory.insert(:taxon, book: book, category: "issf", parent_species: species)

      obs = insert(:observation, taxon_key: Ornitho.Schema.Taxon.key(taxon))

      result = Kjogvi.Birding.Lifelist.generate(obs.card.user)
      assert hd(result).species.name_sci == species.name_sci
    end

    test "uses subspecies observation date if it is earlier than the full species" do
      user = user_fixture()
      book = Ornitho.Factory.insert(:book)
      species = Ornitho.Factory.insert(:taxon, book: book, category: "species")

      subspecies =
        Ornitho.Factory.insert(:taxon, book: book, category: "issf", parent_species: species)

      card1 = insert(:card, observ_date: ~D[2022-06-11], user: user)
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(subspecies))
      card2 = insert(:card, observ_date: ~D[2023-08-19], user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(species))

      result = Kjogvi.Birding.Lifelist.generate(user)
      assert length(result)
      assert hd(result).observ_date == card1.observ_date
    end

    test "does not include spuh observation" do
      taxon = Ornitho.Factory.insert(:taxon, category: "spuh")
      obs = insert(:observation, taxon_key: Ornitho.Schema.Taxon.key(taxon))

      result = Kjogvi.Birding.Lifelist.generate(obs.card.user)
      assert result == []
    end

    test "filtered by year" do
      user = user_fixture()
      taxon1 = Ornitho.Factory.insert(:taxon)
      card1 = insert(:card, observ_date: ~D"2022-11-18", user: user)
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon1))
      taxon2 = Ornitho.Factory.insert(:taxon)
      card2 = insert(:card, observ_date: ~D"2023-07-16", user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon2))

      result = Kjogvi.Birding.Lifelist.generate(user, year: 2022)
      assert length(result) == 1
    end

    test "filtered by missing year" do
      user = user_fixture()
      taxon1 = Ornitho.Factory.insert(:taxon)
      card1 = insert(:card, observ_date: ~D"2022-11-18", user: user)
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon1))
      taxon2 = Ornitho.Factory.insert(:taxon)
      card2 = insert(:card, observ_date: ~D"2023-07-16", user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon2))

      result = Kjogvi.Birding.Lifelist.generate(user, year: 2005)
      assert result == []
    end

    test "filtered by country" do
      user = user_fixture()
      ukraine = insert(:location, slug: "ukraine", name_en: "Ukraine", location_type: "country")
      usa = insert(:location, slug: "usa", name_en: "United States", location_type: "country")
      brovary = insert(:location, slug: "brovary", name_en: "Brovary", ancestry: [ukraine.id])

      taxon1 = Ornitho.Factory.insert(:taxon)
      card1 = insert(:card, location: brovary, user: user)
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon1))
      taxon2 = Ornitho.Factory.insert(:taxon)
      card2 = insert(:card, location: usa, user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon2))

      result = Kjogvi.Birding.Lifelist.generate(user, location: ukraine)
      assert length(result) == 1
    end

    test "filtered by location" do
      user = user_fixture()
      ukraine = insert(:location, slug: "ukraine", name_en: "Ukraine", location_type: "country")
      usa = insert(:location, slug: "usa", name_en: "United States", location_type: "country")
      brovary = insert(:location, slug: "brovary", name_en: "Brovary", ancestry: [ukraine.id])

      taxon1 = Ornitho.Factory.insert(:taxon)
      card1 = insert(:card, location: brovary, user: user)
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon1))
      taxon2 = Ornitho.Factory.insert(:taxon)
      card2 = insert(:card, location: usa, user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon2))

      result = Kjogvi.Birding.Lifelist.generate(user, location: brovary)
      assert length(result) == 1
    end

    test "filtered by year and country" do
      user = user_fixture()
      ukraine = insert(:location, slug: "ukraine", name_en: "Ukraine", location_type: "country")
      usa = insert(:location, slug: "usa", name_en: "United States", location_type: "country")
      brovary = insert(:location, slug: "brovary", name_en: "Brovary", ancestry: [ukraine.id])

      taxon1 = Ornitho.Factory.insert(:taxon)
      card1 = insert(:card, observ_date: ~D"2022-11-18", location: brovary, user: user)
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon1))
      taxon2 = Ornitho.Factory.insert(:taxon)
      card2 = insert(:card, observ_date: ~D"2023-07-16", location: brovary, user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon2))
      taxon3 = Ornitho.Factory.insert(:taxon)
      card2 = insert(:card, observ_date: ~D"2022-07-16", location: usa, user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon3))

      result = Kjogvi.Birding.Lifelist.generate(user, location: ukraine, year: 2022)
      assert length(result) == 1
    end

    test "filtered by special location" do
      user = user_fixture()
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

      taxon1 = Ornitho.Factory.insert(:taxon)
      card1 = insert(:card, observ_date: ~D"2022-11-18", location: locus1, user: user)
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon1))

      # Locus 3 is a child of locus 2, so it should be included
      taxon2 = Ornitho.Factory.insert(:taxon)
      card2 = insert(:card, observ_date: ~D"2023-07-16", location: locus3, user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon2))

      taxon3 = Ornitho.Factory.insert(:taxon)
      card2 = insert(:card, observ_date: ~D"2022-07-16", location: locus4, user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon3))

      result = Kjogvi.Birding.Lifelist.generate(user, location: locus_5mr)
      assert length(result) == 2
    end
  end
end
