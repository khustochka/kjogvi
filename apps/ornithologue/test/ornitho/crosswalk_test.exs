defmodule Ornitho.CrosswalkTest do
  @moduledoc false

  use Ornitho.RepoCase, async: true

  alias Ornitho.Crosswalk
  alias Ornitho.Schema.Taxon

  setup do
    %{source: insert(:book), target: insert(:book, slug: "avilist")}
  end

  # Loaded the way `Ornithologue.get_taxa_and_species/2` returns them.
  defp load(taxa) do
    taxa |> Enum.map(&Taxon.key/1) |> Ornithologue.get_taxa_and_species(format: :full)
  end

  defp match(taxa, book), do: taxa |> load() |> Map.values() |> Crosswalk.match(book)

  test "a taxon of the target book matches itself", %{source: source} do
    spuh = insert(:taxon, book: source, category: "spuh")

    assert {:taxon, %Taxon{id: id}} = match([spuh], source)[Taxon.key(spuh)]
    assert id == spuh.id
  end

  test "matches by concept, even across renames", %{source: source, target: target} do
    taxon = insert(:taxon, book: source, taxon_concept_id: "avibase-1", name_sci: "A a")
    twin = insert(:taxon, book: target, taxon_concept_id: "avibase-1", name_sci: "A renamed")

    assert {:taxon, %Taxon{id: id, book: %{id: book_id}}} =
             match([taxon], target)[Taxon.key(taxon)]

    assert {id, book_id} == {twin.id, target.id}
  end

  test "the same name with a different concept is not a match", %{source: source, target: target} do
    taxon = insert(:taxon, book: source, taxon_concept_id: "avibase-broad", name_sci: "A a")
    insert(:taxon, book: target, taxon_concept_id: "avibase-narrow", name_sci: "A a")

    assert match([taxon], target)[Taxon.key(taxon)] == :unmatched
  end

  test "a taxon without a species still matches by concept", %{source: source, target: target} do
    slash = insert(:taxon, book: source, category: "slash", taxon_concept_id: "avibase-2")
    species = insert(:taxon, book: target, taxon_concept_id: "avibase-2")

    assert {:taxon, %Taxon{id: id}} = match([slash], target)[Taxon.key(slash)]
    assert id == species.id
  end

  test "an unmatched subspecies falls back to its species", %{source: source, target: target} do
    species = insert(:taxon, book: source, taxon_concept_id: "avibase-3")
    ssp = insert(:taxon, book: source, category: "issf", parent_species: species)
    target_species = insert(:taxon, book: target, taxon_concept_id: "avibase-3")

    assert {:species, %Taxon{id: id}} = match([ssp], target)[Taxon.key(ssp)]
    assert id == target_species.id
  end

  test "taxa without a species are not matched; species without a counterpart are unmatched",
       %{source: source, target: target} do
    spuh = insert(:taxon, book: source, category: "spuh")
    species = insert(:taxon, book: source)
    ssp = insert(:taxon, book: source, category: "issf", parent_species: species)

    result = match([spuh, species, ssp], target)

    assert result[Taxon.key(spuh)] == :no_species
    assert result[Taxon.key(species)] == :unmatched
    assert result[Taxon.key(ssp)] == :unmatched
  end
end
