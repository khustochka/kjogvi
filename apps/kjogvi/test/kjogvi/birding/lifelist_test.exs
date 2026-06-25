defmodule Kjogvi.Birding.LifelistTest do
  alias Kjogvi.Factory
  alias Kjogvi.Birding.Lifelist
  use Kjogvi.DataCase, async: true

  import Kjogvi.AccountsFixtures

  describe "years/1" do
    test "returns years that have cards and observation" do
      user = user_fixture()
      scope = %Kjogvi.Scope{subject_user: user, area: :user}
      {taxon, _} = Factory.create_species_taxon_with_page()
      card1 = insert(:card, observ_date: ~D"2022-11-18", user: user)
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon))
      card2 = insert(:card, observ_date: ~D"2023-07-16", user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon))
      assert Kjogvi.Birding.Lifelist.years(scope) == [2022, 2023]
    end

    test "returns years in correct order" do
      user = user_fixture()
      scope = %Kjogvi.Scope{subject_user: user, area: :user}
      {taxon, _} = Factory.create_species_taxon_with_page()
      card1 = insert(:card, observ_date: ~D"2023-11-18", user: user)
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon))
      card2 = insert(:card, observ_date: ~D"2022-07-16", user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon))
      assert Kjogvi.Birding.Lifelist.years(scope) == [2022, 2023]
    end

    test "does not include years with unreported observations only" do
      user = user_fixture()
      scope = %Kjogvi.Scope{subject_user: user, area: :user}
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
      scope = %Kjogvi.Scope{subject_user: user, area: :user}
      {taxon, _} = Factory.create_species_taxon_with_page()
      card1 = insert(:card, observ_date: ~D"2022-11-18", user: user)
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon))
      card2 = insert(:card, observ_date: ~D"2023-07-16", user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon))
      assert Kjogvi.Birding.Lifelist.months(scope) == [7, 11]
    end

    test "returns months in correct order" do
      user = user_fixture()
      scope = %Kjogvi.Scope{subject_user: user, area: :user}
      {taxon, _} = Factory.create_species_taxon_with_page()
      card1 = insert(:card, observ_date: ~D"2023-11-18", user: user)
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon))
      card2 = insert(:card, observ_date: ~D"2022-07-16", user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon))
      assert Kjogvi.Birding.Lifelist.months(scope) == [7, 11]
    end

    test "does not include years with unreported observations only" do
      user = user_fixture()
      scope = %Kjogvi.Scope{subject_user: user, area: :user}
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
      scope = %Kjogvi.Scope{subject_user: user, area: :user}
      taxon = Ornitho.Factory.insert(:taxon, category: "species")
      insert(:observation, taxon_key: Ornitho.Schema.Taxon.key(taxon))

      result = Kjogvi.Birding.Lifelist.generate(scope)
      assert result.list == []
    end

    test "includes species observation" do
      {taxon, _} = Factory.create_species_taxon_with_page()
      obs = insert(:observation, taxon_key: Ornitho.Schema.Taxon.key(taxon))
      scope = %Kjogvi.Scope{subject_user: obs.card.user, area: :user}

      result = Kjogvi.Birding.Lifelist.generate(scope)

      assert length(result.list) == 1
      assert hd(result.list).species_page.name_sci == taxon.name_sci
    end

    test "includes subspecies observation" do
      {%{parent_species: species} = taxon, _} = Factory.create_subspecies_taxon_with_page()

      obs = insert(:observation, taxon_key: Ornitho.Schema.Taxon.key(taxon))

      scope = %Kjogvi.Scope{subject_user: obs.card.user, area: :user}

      result = Kjogvi.Birding.Lifelist.generate(scope)

      assert length(result.list) == 1
      assert hd(result.list).species_page.name_sci == species.name_sci
    end

    test "uses subspecies observation date if it is earlier than the full species" do
      user = user_fixture()
      scope = %Kjogvi.Scope{subject_user: user, area: :user}
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

      scope = %Kjogvi.Scope{subject_user: obs.card.user, area: :user}

      result = Kjogvi.Birding.Lifelist.generate(scope)
      assert result.list == []
    end

    test "does not include observation with unknown taxon key" do
      obs =
        insert(:observation, taxon_key: "/abc/v1/taxon")

      scope = %Kjogvi.Scope{subject_user: obs.card.user, area: :user}

      result = Kjogvi.Birding.Lifelist.generate(scope)
      assert result.list == []
    end

    test "filtered by year" do
      user = user_fixture()
      scope = %Kjogvi.Scope{subject_user: user, area: :user}
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
      scope = %Kjogvi.Scope{subject_user: user, area: :user}
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
      scope = %Kjogvi.Scope{subject_user: user, area: :user}
      ukraine = insert(:country, slug: "ukraine", name_en: "Ukraine")
      usa = insert(:country, slug: "usa", name_en: "United States")

      brovary =
        insert(:location,
          slug: "brovary",
          name_en: "Brovary",
          location_type: "city",
          country: ukraine
        )

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
      scope = %Kjogvi.Scope{subject_user: user, area: :user}
      ukraine = insert(:country, slug: "ukraine", name_en: "Ukraine")
      usa = insert(:country, slug: "usa", name_en: "United States")

      brovary =
        insert(:location,
          slug: "brovary",
          name_en: "Brovary",
          location_type: "city",
          country: ukraine
        )

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
      scope = %Kjogvi.Scope{subject_user: user, area: :user}
      ukraine = insert(:country, slug: "ukraine", name_en: "Ukraine")
      usa = insert(:country, slug: "usa", name_en: "United States")

      brovary =
        insert(:location,
          slug: "brovary",
          name_en: "Brovary",
          location_type: "city",
          country: ukraine
        )

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
      scope = %Kjogvi.Scope{subject_user: user, area: :user}
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
      scope = %Kjogvi.Scope{subject_user: user, area: :user}
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
      scope = %Kjogvi.Scope{subject_user: user, area: :user}

      locus1 =
        insert(:location, slug: "bunns_creek", name_en: "Bunn's Creek", location_type: "site")

      locus2 =
        insert(:location, slug: "kildonan_park", name_en: "Kildonan Park", location_type: "city")

      locus3 =
        insert(:location,
          slug: "witches_hut",
          name_en: "Witch's Hut",
          location_type: "site",
          city_id: locus2.id
        )

      locus4 =
        insert(:location,
          slug: "assiniboine_park",
          name_en: "Assiniboine Park",
          location_type: "site"
        )

      locus_5mr =
        insert(:special,
          slug: "5mr",
          name_en: "5MR",
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
      scope = %Kjogvi.Scope{subject_user: user, area: :user}
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
      scope = %Kjogvi.Scope{subject_user: user, area: :user}

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
      scope = %Kjogvi.Scope{current_user: user, area: :private}

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
      scope = %Kjogvi.Scope{subject_user: user, area: :user}

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

    test "community scope aggregates observations across all users" do
      user1 = user_fixture()
      user2 = user_fixture()
      scope = %Kjogvi.Scope{area: :community}

      {taxon1, _} = Factory.create_species_taxon_with_page()
      {taxon2, _} = Factory.create_species_taxon_with_page()

      card1 = insert(:card, user: user1)
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon1))
      card2 = insert(:card, user: user2)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon2))

      result = Kjogvi.Birding.Lifelist.generate(scope)

      name_scis = Enum.map(result.list, & &1.species_page.name_sci)
      assert length(result.list) == 2
      assert taxon1.name_sci in name_scis
      assert taxon2.name_sci in name_scis
    end

    test "community scope excludes hidden observations" do
      user = user_fixture()
      scope = %Kjogvi.Scope{area: :community}

      {taxon1, _} = Factory.create_species_taxon_with_page()
      {taxon2, _} = Factory.create_species_taxon_with_page()
      card = insert(:card, user: user)

      insert(:observation,
        card: card,
        taxon_key: Ornitho.Schema.Taxon.key(taxon1),
        hidden: true
      )

      insert(:observation, card: card, taxon_key: Ornitho.Schema.Taxon.key(taxon2))

      result = Kjogvi.Birding.Lifelist.generate(scope)

      assert Enum.map(result.list, & &1.species_page.name_sci) == [taxon2.name_sci]
    end

    test "works with private locations, resolving the public ancestor for display" do
      country = insert(:country, name_en: "Canada")
      city = insert(:location, name_en: "Winnipeg", location_type: "city", country: country)

      private_loc =
        insert(:location,
          name_en: "Secret Patch",
          location_type: "site",
          is_private: true,
          country: country,
          city_id: city.id
        )

      user = user_fixture()
      card = insert(:card, user: user, location: private_loc)

      {taxon, _} = Factory.create_species_taxon_with_page()
      insert(:observation, card: card, taxon_key: Ornitho.Schema.Taxon.key(taxon))

      scope = %Kjogvi.Scope{subject_user: user, area: :user}

      result = Kjogvi.Birding.Lifelist.generate(scope)

      assert length(result.list) == 1
      # The public-area lifelist must not surface the private location: its public
      # name drops the private segment, leaving the public ancestors.
      [lifer] = result.list
      assert Kjogvi.Geo.Location.long_name(:public, lifer.location) == "Winnipeg, Canada"
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

      scope = %Kjogvi.Scope{subject_user: user, area: :user}
      result = Kjogvi.Birding.Lifelist.generate(scope, exclude_heard_only: true)

      assert length(result.list) == 1
      assert length(result.extras.heard_only.list) == 1
    end

    test "heard only extras is empty when all species have been seen" do
      user = user_fixture()
      scope = %Kjogvi.Scope{subject_user: user, area: :user}

      {taxon, _} = Factory.create_species_taxon_with_page()
      card = insert(:card, observ_date: ~D"2023-06-01", user: user)
      insert(:observation, card: card, taxon_key: Ornitho.Schema.Taxon.key(taxon))

      result = Kjogvi.Birding.Lifelist.generate(scope, exclude_heard_only: true)

      assert length(result.list) == 1
      assert result.extras.heard_only.list == []
      assert result.extras.heard_only.total == 0
    end

    test "heard only extras respects year filter" do
      user = user_fixture()
      scope = %Kjogvi.Scope{subject_user: user, area: :user}

      {taxon1, _} = Factory.create_species_taxon_with_page()
      card1 = insert(:card, observ_date: ~D"2022-05-10", user: user)
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon1), voice: true)

      {taxon2, _} = Factory.create_species_taxon_with_page()
      card2 = insert(:card, observ_date: ~D"2023-08-15", user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon2), voice: true)

      result = Kjogvi.Birding.Lifelist.generate(scope, exclude_heard_only: true, year: 2022)

      assert result.list == []
      assert length(result.extras.heard_only.list) == 1
      assert hd(result.extras.heard_only.list).species_page.name_sci == taxon1.name_sci
    end

    test "heard only species uses earliest voice-only observation date" do
      user = user_fixture()
      scope = %Kjogvi.Scope{subject_user: user, area: :user}

      {taxon, _} = Factory.create_species_taxon_with_page()
      card1 = insert(:card, observ_date: ~D"2022-03-01", user: user)
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon), voice: true)

      card2 = insert(:card, observ_date: ~D"2023-09-15", user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon), voice: true)

      result = Kjogvi.Birding.Lifelist.generate(scope, exclude_heard_only: true)

      assert result.list == []
      assert length(result.extras.heard_only.list) == 1
      assert hd(result.extras.heard_only.list).observ_date == ~D[2022-03-01]
    end
  end

  describe "generate/2 with sort: :taxonomy" do
    test "orders species by taxonomic sort_order ascending, ignoring date" do
      user = user_fixture()
      scope = %Kjogvi.Scope{subject_user: user, area: :user}

      # Earlier date but later sort_order
      {taxon_late_taxonomy, _} = Factory.create_species_taxon_with_page()
      card_old = insert(:card, observ_date: ~D[2020-01-01], user: user)

      insert(:observation,
        card: card_old,
        taxon_key: Ornitho.Schema.Taxon.key(taxon_late_taxonomy)
      )

      # Later date but earlier sort_order — created first ⇒ smaller sort_order
      {taxon_early_taxonomy, _} = Factory.create_species_taxon_with_page()
      card_recent = insert(:card, observ_date: ~D[2024-06-01], user: user)

      insert(:observation,
        card: card_recent,
        taxon_key: Ornitho.Schema.Taxon.key(taxon_early_taxonomy)
      )

      # Create two species, find which has smaller sort_order via species_pages
      [first_sci, second_sci] =
        [taxon_late_taxonomy, taxon_early_taxonomy]
        |> Enum.sort_by(fn t ->
          Kjogvi.Pages.Species.from_taxon(t).sort_order
        end)
        |> Enum.map(& &1.name_sci)

      result = Kjogvi.Birding.Lifelist.generate(scope, sort: :taxonomy)

      assert Enum.map(result.list, & &1.species_page.name_sci) == [first_sci, second_sci]
    end
  end

  describe "top/3" do
    test "returns the N newest species" do
      user = user_fixture()
      scope = %Kjogvi.Scope{subject_user: user, area: :user}

      {taxon1, _} = Factory.create_species_taxon_with_page()
      card1 = insert(:card, observ_date: ~D[2022-03-10], user: user)
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon1))

      {taxon2, _} = Factory.create_species_taxon_with_page()
      card2 = insert(:card, observ_date: ~D[2023-06-15], user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon2))

      {taxon3, _} = Factory.create_species_taxon_with_page()
      card3 = insert(:card, observ_date: ~D[2024-01-20], user: user)
      insert(:observation, card: card3, taxon_key: Ornitho.Schema.Taxon.key(taxon3))

      result = Lifelist.top(scope, 2)
      assert result.total == 3
      assert length(result.list) == 2
      # Should be ordered by date descending — newest first
      assert hd(result.list).observ_date == ~D[2024-01-20]
    end

    test "returns all species when n exceeds total" do
      user = user_fixture()
      scope = %Kjogvi.Scope{subject_user: user, area: :user}

      {taxon, _} = Factory.create_species_taxon_with_page()
      card = insert(:card, observ_date: ~D[2023-06-15], user: user)
      insert(:observation, card: card, taxon_key: Ornitho.Schema.Taxon.key(taxon))

      result = Lifelist.top(scope, 10)
      assert result.total == 1
      assert length(result.list) == 1
    end

    test "accepts keyword filter" do
      user = user_fixture()
      scope = %Kjogvi.Scope{subject_user: user, area: :user}

      {taxon1, _} = Factory.create_species_taxon_with_page()
      card1 = insert(:card, observ_date: ~D[2022-03-10], user: user)
      insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon1))

      {taxon2, _} = Factory.create_species_taxon_with_page()
      card2 = insert(:card, observ_date: ~D[2023-06-15], user: user)
      insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon2))

      result = Lifelist.top(scope, 5, year: 2022)
      assert result.total == 1
      assert length(result.list) == 1
    end
  end

  describe "location_ids/2" do
    test "returns the country ancestor of a location that has observations" do
      user = user_fixture()
      scope = %Kjogvi.Scope{subject_user: user, area: :user}

      canada = insert(:country, name_en: "Canada")
      winnipeg = insert(:location, location_type: "city", country: canada)

      {taxon, _} = Factory.create_species_taxon_with_page()
      card = insert(:card, user: user, location: winnipeg)
      insert(:observation, card: card, taxon_key: Ornitho.Schema.Taxon.key(taxon))

      ids = Lifelist.location_ids(scope)
      assert canada.id in ids
    end

    test "returns empty list when no observations exist" do
      user = user_fixture()
      scope = %Kjogvi.Scope{subject_user: user, area: :user}

      assert Lifelist.location_ids(scope) == []
    end

    test "includes a country when the observation is at the country itself" do
      user = user_fixture()
      scope = %Kjogvi.Scope{subject_user: user, area: :user}

      canada = insert(:country, name_en: "Canada")

      {taxon, _} = Factory.create_species_taxon_with_page()
      card = insert(:card, user: user, location: canada)
      insert(:observation, card: card, taxon_key: Ornitho.Schema.Taxon.key(taxon))

      ids = Lifelist.location_ids(scope)
      assert canada.id in ids
    end

    test "returns both the country and subdivision1 ancestors" do
      user = user_fixture()
      scope = %Kjogvi.Scope{subject_user: user, area: :user}

      canada = insert(:country, name_en: "Canada")

      manitoba =
        insert(:location, name_en: "Manitoba", location_type: "subdivision1", country: canada)

      winnipeg =
        insert(:location,
          location_type: "city",
          country: canada,
          subdivision1_id: manitoba.id
        )

      {taxon, _} = Factory.create_species_taxon_with_page()
      card = insert(:card, user: user, location: winnipeg)
      insert(:observation, card: card, taxon_key: Ornitho.Schema.Taxon.key(taxon))

      ids = Lifelist.location_ids(scope)
      assert canada.id in ids
      assert manitoba.id in ids
    end

    test "excludes locations below subdivision1 even when they have observations" do
      user = user_fixture()
      scope = %Kjogvi.Scope{subject_user: user, area: :user}

      canada = insert(:country, name_en: "Canada")
      winnipeg = insert(:location, location_type: "city", country: canada)

      {taxon, _} = Factory.create_species_taxon_with_page()
      card = insert(:card, user: user, location: winnipeg)
      insert(:observation, card: card, taxon_key: Ornitho.Schema.Taxon.key(taxon))

      ids = Lifelist.location_ids(scope)
      assert winnipeg.id not in ids
      assert ids == [canada.id]
    end
  end

  describe "generate/2 result structure" do
    test "returns a Result struct with correct fields" do
      user = user_fixture()
      scope = %Kjogvi.Scope{subject_user: user, area: :user}

      {taxon, _} = Factory.create_species_taxon_with_page()
      card = insert(:card, user: user)
      insert(:observation, card: card, taxon_key: Ornitho.Schema.Taxon.key(taxon))

      result = Lifelist.generate(scope)
      assert %Lifelist.Result{} = result
      assert result.user == user
      assert result.visibility == :public
      assert result.total == 1
      assert %Lifelist.Filter{} = result.filter
    end
  end

  describe "Lifelist.Filter.discombo/1" do
    test "returns {:ok, filter} for valid options" do
      assert {:ok, %Lifelist.Filter{year: 2023}} = Lifelist.Filter.discombo(year: 2023)
    end

    test "returns {:ok, filter} with defaults" do
      assert {:ok, filter} = Lifelist.Filter.discombo([])
      assert filter.year == nil
      assert filter.month == nil
      assert filter.motorless == false
      assert filter.exclude_heard_only == false
    end

    test "returns error for invalid options" do
      assert {:error, _} = Lifelist.Filter.discombo(invalid_key: true)
    end
  end
end
