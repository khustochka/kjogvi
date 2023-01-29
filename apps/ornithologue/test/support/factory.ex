defmodule Ornitho.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: Ornitho.Repo

  def book_factory do
    %Ornitho.Schema.Book{
      slug: "ebird",
      version: "v2022",
      name: "eBird/Clements",
      extras: %{
        "authors" => """
        Clements, J. F., T. S. Schulenberg, M. J. Iliff, T. A. Fredericks, J. A. Gerbracht, D. Lepage, S. M. Billerman, B. L. Sullivan, and C. L. Wood
        """
      }
    }
  end
end
