defmodule Ornithologue do
  @moduledoc """
  Documentation for `Ornithologue`.
  """

  import Ecto.Query

  alias Ornitho.Repo
  # alias Ornitho.Schema.Book
  alias Ornitho.Schema.Taxon

  def get_taxa_and_species(keys_list) do
    by_book =
        keys_list
        |> Enum.reduce(%{}, fn key, acc ->
            ["", book_slug, book_version, taxon_code] = String.split(key, "/")

            book_sig = {book_slug, book_version}
            list = acc[book_sig] || []

            Map.put(acc, book_sig, [taxon_code | list])
        end)

  #   sig_fragment =
  #     for {s, v} <- Map.keys(by_book) do
  #       "('#{s}', '#{v}')"
  #     end
  #     |> Enum.join(",")
  #  books =
  #   (from b in Book,
  #     where: fragment("(?, ?) IN (?)" , b.slug, b.version, ^sig_fragment))
  #   |> Repo.all

    by_book
      |> Enum.reduce(%{}, fn {{slug, version}, taxa_codes}, acc ->
        grouped =
          Taxon
          |> join(:inner, [t], b in assoc(t, :book))
          |> where([_, b], b.slug == ^slug and b.version == ^version)
          |> where([t, _], t.code in ^taxa_codes)
          |> preload(:book)
          |> Repo.all()
          |> Enum.group_by(&Taxon.key/1)
          |> Enum.map(fn {key, [val | _]} -> {key, val} end)
          |> Enum.into(%{})
        acc
        |> Map.merge(grouped)
      end)
  end
end
