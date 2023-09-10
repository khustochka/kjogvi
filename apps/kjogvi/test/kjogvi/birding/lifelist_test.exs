defmodule Kjogvi.Birding.LifelistTest do
  use Kjogvi.DataCase, async: true

  describe "years/1" do
    test "returns years that have cards and observation" do
      taxon = Ornitho.Factory.insert(:taxon)
      card1 = insert(:card, observ_date: ~D"2022-11-18")
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon))
      card2 = insert(:card, observ_date: ~D"2023-07-16")
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon))
      assert Kjogvi.Birding.Lifelist.years() == [2022, 2023]
    end

    test "returns years in correct order" do
      taxon = Ornitho.Factory.insert(:taxon)
      card1 = insert(:card, observ_date: ~D"2023-11-18")
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon))
      card2 = insert(:card, observ_date: ~D"2022-07-16")
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon))
      assert Kjogvi.Birding.Lifelist.years() == [2022, 2023]
    end

    test "does not include years with unreported observations only" do
      taxon = Ornitho.Factory.insert(:taxon)
      card1 = insert(:card, observ_date: ~D"2023-11-18")

      insert(:observation,
        card: card1,
        taxon_key: Ornitho.Schema.Taxon.key(taxon),
        unreported: true
      )

      card2 = insert(:card, observ_date: ~D"2022-07-16")
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon))
      assert Kjogvi.Birding.Lifelist.years() == [2022]
    end
  end

  describe "generate/1" do
    test "works with no observations" do
      result = Kjogvi.Birding.Lifelist.generate()
      assert result == []
    end

    test "includes species observation" do
      taxon = Ornitho.Factory.insert(:taxon, category: "species")
      insert(:observation, taxon_key: Ornitho.Schema.Taxon.key(taxon))

      result = Kjogvi.Birding.Lifelist.generate()
      assert hd(result).species.name_sci == taxon.name_sci
    end

    test "includes subspecies observation" do
      book = Ornitho.Factory.insert(:book)
      species = Ornitho.Factory.insert(:taxon, book: book, category: "species")

      taxon =
        Ornitho.Factory.insert(:taxon, book: book, category: "issf", parent_species: species)

      insert(:observation, taxon_key: Ornitho.Schema.Taxon.key(taxon))

      result = Kjogvi.Birding.Lifelist.generate()
      assert hd(result).species.name_sci == species.name_sci
    end

    test "uses subspecies observation date if it is earlier than the full species" do
      book = Ornitho.Factory.insert(:book)
      species = Ornitho.Factory.insert(:taxon, book: book, category: "species")
      subspecies =
        Ornitho.Factory.insert(:taxon, book: book, category: "issf", parent_species: species)

      card1 = insert(:card, observ_date: ~D[2022-06-11])
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(subspecies))
      card2 = insert(:card, observ_date: ~D[2023-08-19])
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(species))

      result = Kjogvi.Birding.Lifelist.generate()
      assert length(result)
      assert hd(result).observ_date == card1.observ_date
    end

    test "does not include spuh observation" do
      taxon = Ornitho.Factory.insert(:taxon, category: "spuh")
      insert(:observation, taxon_key: Ornitho.Schema.Taxon.key(taxon))

      result = Kjogvi.Birding.Lifelist.generate()
      assert result == []
    end

    test "filtered by year" do
      taxon = Ornitho.Factory.insert(:taxon)
      card1 = insert(:card, observ_date: ~D"2022-11-18")
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon))
      card2 = insert(:card, observ_date: ~D"2023-07-16")
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon))

      result = Kjogvi.Birding.Lifelist.generate(%{year: 2022})
      assert length(result) == 1
    end

    test "filtered by missing year" do
      taxon = Ornitho.Factory.insert(:taxon)
      card1 = insert(:card, observ_date: ~D"2022-11-18")
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon))
      card2 = insert(:card, observ_date: ~D"2023-07-16")
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon))

      result = Kjogvi.Birding.Lifelist.generate(%{year: 2005})
      assert result == []
    end
  end
end
