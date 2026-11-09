defmodule Kjogvi.Birding.TaxaLifelistTest do
  use Kjogvi.DataCase, async: true

  import Kjogvi.AccountsFixtures

  alias Kjogvi.Birding.Lifelist
  alias Kjogvi.Birding.TaxaLifelist
  alias Ornitho.Schema.Taxon

  setup do
    user = user_fixture()
    book = Ornitho.Factory.insert(:book)
    species = Ornitho.Factory.insert(:taxon, book: book, name_en: "Mallard")

    subspecies =
      Ornitho.Factory.insert(:taxon,
        book: book,
        category: "issf",
        name_en: "Mallard (Northern)",
        parent_species: species
      )

    spuh = Ornitho.Factory.insert(:taxon, book: book, category: "spuh", name_en: "duck sp.")

    %{
      user: user,
      scope: %Kjogvi.Scope{current_user: user, area: :private},
      book: book,
      species: species,
      subspecies: subspecies,
      spuh: spuh
    }
  end

  defp observe(user, taxon, date, attrs \\ []) do
    {checklist_attrs, attrs} = Keyword.split(attrs, [:location, :motorless])
    checklist = insert(:checklist, [user: user, observ_date: date] ++ checklist_attrs)

    insert(
      :observation,
      Keyword.merge([checklist: checklist, taxon_key: Taxon.key(taxon)], attrs)
    )
  end

  defp names(entries), do: Enum.map(entries, &{&1.taxon.name_en, &1.observ_date})

  defp generate(ctx, filter) do
    TaxaLifelist.generate(ctx.scope, Lifelist.Filter.discombo!([book: ctx.book] ++ filter))
  end

  describe "generate/2" do
    test "lists every recorded taxon with its first record, in taxonomic order", ctx do
      observe(ctx.user, ctx.spuh, ~D[2020-01-01])
      observe(ctx.user, ctx.subspecies, ~D[2021-05-01])
      observe(ctx.user, ctx.species, ~D[2022-03-01])
      observe(ctx.user, ctx.species, ~D[2019-03-01])

      assert names(generate(ctx, sort: :taxonomy)) == [
               {"Mallard", ~D[2019-03-01]},
               {"Mallard (Northern)", ~D[2021-05-01]},
               {"duck sp.", ~D[2020-01-01]}
             ]
    end

    test "date sort puts the newest first record first", ctx do
      observe(ctx.user, ctx.spuh, ~D[2020-01-01])
      observe(ctx.user, ctx.species, ~D[2022-03-01])

      assert names(generate(ctx, sort: :date)) == [
               {"Mallard", ~D[2022-03-01]},
               {"duck sp.", ~D[2020-01-01]}
             ]
    end

    test "excludes other books, other users, and unreported observations", ctx do
      observe(ctx.user, Ornitho.Factory.insert(:taxon), ~D[2020-01-01])
      observe(user_fixture(), ctx.species, ~D[2020-01-01])
      observe(ctx.user, ctx.spuh, ~D[2020-01-01], unreported: true)

      assert generate(ctx, []) == []
    end

    test "applies lifelist filters", ctx do
      observe(ctx.user, ctx.spuh, ~D[2020-01-01])
      observe(ctx.user, ctx.species, ~D[2022-03-01])

      assert names(generate(ctx, year: 2020)) == [{"duck sp.", ~D[2020-01-01]}]
    end

    test "species_only rolls taxa up to species with the earliest record and drops the rest",
         ctx do
      observe(ctx.user, ctx.spuh, ~D[2018-01-01])
      observe(ctx.user, ctx.species, ~D[2022-03-01])
      subspecies_obs = observe(ctx.user, ctx.subspecies, ~D[2021-05-01])

      assert [entry] = generate(ctx, species_only: true)
      assert entry.taxon.id == ctx.species.id
      assert entry.observ_date == ~D[2021-05-01]
      assert entry.id == subspecies_obs.id
    end
  end

  describe "Lifelist.generate/2 with a book" do
    test "years and months come from the book's observations", ctx do
      observe(ctx.user, ctx.spuh, ~D[2020-04-01])

      assert Lifelist.years(ctx.scope, book: ctx.book) == [2020]
      assert Lifelist.months(ctx.scope, book: ctx.book) == [4]
      assert Lifelist.years(ctx.scope) == []
    end
  end
end
