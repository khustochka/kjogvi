defmodule Kjogvi.Birding.TaxaLifelistTest do
  use Kjogvi.DataCase, async: true

  import Kjogvi.AccountsFixtures

  alias Kjogvi.Birding.Lifelist
  alias Kjogvi.Birding.TaxaLifelist
  alias Ornitho.Schema.Taxon

  setup do
    user = user_fixture()
    book = Ornitho.Factory.insert(:book)

    species =
      Ornitho.Factory.insert(:taxon, book: book, name_en: "Mallard", taxon_concept_id: "mallard")

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

  defp generate(ctx, filter), do: generate_result(ctx, filter).list

  defp generate_result(ctx, filter) do
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

    test "excludes other users and unreported observations", ctx do
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

  describe "generate/2 with observations from another book" do
    setup ctx do
      other = Ornitho.Factory.insert(:book, slug: "other")

      %{
        other_species:
          Ornitho.Factory.insert(:taxon,
            book: other,
            taxon_concept_id: "mallard",
            name_en: "Mallard (other)"
          ),
        other_spuh: Ornitho.Factory.insert(:taxon, book: other, category: "spuh"),
        other_unmatched: Ornitho.Factory.insert(:taxon, book: other, name_en: "Lost Duck")
      }
    end

    test "matches them into the book, keeping the earliest record per taxon", ctx do
      observe(ctx.user, ctx.species, ~D[2022-03-01])
      observe(ctx.user, ctx.other_species, ~D[2020-01-01])

      assert names(generate(ctx, [])) == [{"Mallard", ~D[2020-01-01]}]
    end

    test "reports unmatched taxa and those without a species separately", ctx do
      observe(ctx.user, ctx.other_spuh, ~D[2020-01-01])
      observe(ctx.user, ctx.other_unmatched, ~D[2020-01-01])
      observe(ctx.user, ctx.spuh, ~D[2020-01-01])
      unknown = observe(ctx.user, ctx.spuh, ~D[2020-01-01], taxon_key: "/gone/v1/x")

      result = generate_result(ctx, [])

      assert names(result.list) == [{"duck sp.", ~D[2020-01-01]}]
      assert [%{taxon: %{id: unmatched_id}}, %{taxon: nil, id: unknown_id}] = result.unmatched
      assert {unmatched_id, unknown_id} == {ctx.other_unmatched.id, unknown.id}
      assert [%{taxon: %{id: no_species_id}}] = result.no_species
      assert no_species_id == ctx.other_spuh.id
    end
  end

  describe "species_count/1" do
    test "counts distinct species, ignoring taxa without one", ctx do
      observe(ctx.user, ctx.species, ~D[2020-01-01])
      observe(ctx.user, ctx.subspecies, ~D[2020-01-01])
      observe(ctx.user, ctx.spuh, ~D[2020-01-01])

      assert generate(ctx, []) |> TaxaLifelist.species_count() == 1
    end
  end

  describe "Lifelist with a book" do
    test "generate/2 puts unmatched and no-species taxa in extras", ctx do
      observe(ctx.user, Ornitho.Factory.insert(:taxon, category: "spuh"), ~D[2020-04-01])

      assert %{list: [], extras: %{unmatched: [], no_species: [_]}} =
               Lifelist.generate(ctx.scope, book: ctx.book)
    end

    test "years and months come from all observations, species page or not", ctx do
      observe(ctx.user, Ornitho.Factory.insert(:taxon, category: "spuh"), ~D[2020-04-01])

      assert Lifelist.years(ctx.scope, book: ctx.book) == [2020]
      assert Lifelist.months(ctx.scope, book: ctx.book) == [4]
      assert Lifelist.years(ctx.scope) == []
    end
  end
end
