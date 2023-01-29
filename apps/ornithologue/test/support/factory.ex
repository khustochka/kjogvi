defmodule Ornitho.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: Ornitho.Repo

  def book_factory do
    %Ornitho.Schema.Book{
      slug: "ebird",
      version: sequence(:book_version, &"v#{&1}", start_at: 2020),
      name: "eBird/Clements",
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
      name_sci: "Cuculus canorus",
      name_en: "Common Cuckoo",
      code: "comcuc",
      category: "species",
      authority: "Linnaeus, 1758",
      authority_brackets: false,
      protonym: "Cuculus canorus",
      order: "Cuculiformes",
      family: "Cuculidae",
      sort_order: sequence(:sort_order, &(&1)),
      extras: %{
        "family_en" => "Cuckoos",
        "species_group" => "Cuckoos"
      }
    }
  end
end
