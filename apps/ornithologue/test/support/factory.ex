defmodule Ornitho.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: Kjogvi.OrnithoRepo

  def book_factory do
    %Ornitho.Schema.Book{
      slug: "ebird",
      version: sequence(:book_version, &"v#{&1}", start_at: 2020),
      name: "eBird/Clements",
      publication_date: ~D[2019-08-15],
      extras: %{
        "authors" => """
        Clements, J. F., T. S. Schulenberg, M. J. Iliff, T. A. Fredericks, J. A. Gerbracht, D. Lepage, S. M. Billerman, B. L. Sullivan, and C. L. Wood
        """
      }
    }
  end

  def taxon_factory do
    %Ornitho.Schema.Taxon{
      book: build(:book),
      name_sci: sequence(:taxon_code, &"Cuculus canorus - #{&1}"),
      name_en: sequence(:taxon_code, &"Common Cuckoo - #{&1}"),
      code: sequence(:taxon_code, &"comcuc#{&1}"),
      category: "species",
      authority: "Linnaeus, 1758",
      authority_brackets: false,
      protonym: "Cuculus canorus",
      order: "Cuculiformes",
      family: "Cuculidae",
      sort_order: sequence(:sort_order, & &1),
      extras: %{
        "family_en" => "Cuckoos",
        "species_group" => "Cuckoos"
      }
    }
  end
end
