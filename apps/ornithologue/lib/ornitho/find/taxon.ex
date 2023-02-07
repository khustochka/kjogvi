defmodule Ornitho.Find.Taxon do
  @moduledoc """
  Functions for fetching Taxa.
  """

  import Ecto.Query

  alias Ornitho.Repo
  # alias Ornitho.Query
  alias Ornitho.Schema.{Book, Taxon}

  @spec by_name_sci(%Book{}, String.t()) :: %Taxon{} | nil
  def by_name_sci(book, name_sci) do
    book
    |> Ecto.assoc(:taxa)
    |> where(name_sci: ^name_sci)
    |> Repo.one()
  end
end
