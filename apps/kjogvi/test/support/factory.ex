defmodule Kjogvi.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: Kjogvi.Repo

  # A `:site` under the shared country. Use `country_factory` for a top-level
  # country; pass `country:` to place it under a different one.
  def location_factory(attrs) do
    base = %Kjogvi.Geo.Location{
      slug: sequence(:slug, &"winnipeg#{&1}"),
      name_en: sequence(:slug, &"Winnipeg - #{&1}"),
      location_type: :site
    }

    # The shared country inserts on access, so only reach for it when the caller
    # didn't pin one — otherwise every override would leave a stray country.
    base =
      if Map.has_key?(attrs, :country),
        do: base,
        else: %{base | country: shared_country()}

    merge_attributes(base, attrs)
  end

  def country_factory do
    %Kjogvi.Geo.Location{
      slug: sequence(:slug, &"country#{&1}"),
      name_en: sequence(:name_en, &"Country #{&1}"),
      location_type: :country
    }
  end

  def subdivision1_factory do
    %Kjogvi.Geo.Location{
      slug: sequence(:slug, &"subdivision#{&1}"),
      name_en: sequence(:name_en, &"Subdivision #{&1}"),
      location_type: :subdivision1
    }
  end

  def special_factory do
    %Kjogvi.Geo.Location{
      slug: sequence(:slug, &"special#{&1}"),
      name_en: sequence(:name_en, &"Special #{&1}"),
      location_type: :special
    }
  end

  @doc """
  One country reused across the current test, inserted lazily and memoized in the
  process (the Ecto sandbox makes that test-scoped). Backs `location_factory`.
  """
  def shared_country do
    case Process.get(:factory_shared_country) do
      nil ->
        country = insert(:country)
        Process.put(:factory_shared_country, country)
        country

      country ->
        country
    end
  end

  def checklist_factory do
    %Kjogvi.Birding.Checklist{
      user: Kjogvi.AccountsFixtures.user_fixture(),
      observ_date: "2023-08-29",
      effort_type: "INCIDENTAL",
      location: build(:location)
    }
  end

  def observation_factory do
    %Kjogvi.Birding.Observation{
      checklist: build(:checklist)
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
