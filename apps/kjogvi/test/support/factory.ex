defmodule Kjogvi.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: Kjogvi.Repo

  def location_factory do
    %Kjogvi.Geo.Location{
      slug: sequence(:slug, &"winnipeg#{&1}"),
      name_en: sequence(:slug, &"Winnipeg - #{&1}")
    }
  end

  def card_factory do
    %Kjogvi.Birding.Card{
      user: Kjogvi.UsersFixtures.user_fixture(),
      observ_date: "2023-08-29",
      effort_type: "INCIDENTAL",
      location: build(:location)
    }
  end

  def main_user_card_factory do
    struct!(
      card_factory(),
      %{user: Kjogvi.Settings.main_user()}
    )
  end

  def observation_factory do
    %Kjogvi.Birding.Observation{
      card: build(:card)
    }
  end

  def create_species_taxon_with_page(attrs \\ []) do
    taxon_attrs =
      Map.new(attrs)
      |> Map.put_new(:category, "species")

    taxon = Ornitho.Factory.insert(:taxon, taxon_attrs)
    species_page = Kjogvi.Pages.Promotion.promote_taxon(taxon)

    {taxon, species_page}
  end

  def create_subspecies_taxon_with_page(attrs \\ []) do
    book = attrs[:book] || Ornitho.Factory.insert(:book)

    species = Ornitho.Factory.insert(:taxon, book: book)

    taxon_attrs =
      Map.new(attrs)
      |> Map.put_new(:category, "issf")
      |> Map.put_new(:book, book)
      |> Map.put_new(:parent_species, species)

    taxon = Ornitho.Factory.insert(:taxon, taxon_attrs)
    species_page = Kjogvi.Pages.Promotion.promote_taxon(taxon)

    {taxon, species_page}
  end
end
