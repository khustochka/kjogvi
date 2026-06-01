defmodule Kjogvi.Search.WordMatch do
  @moduledoc """
  Shared word-boundary matching for in-memory search ranking.

  Both `Kjogvi.Search.Taxon` and `Kjogvi.Search.Location` rank results by how a
  query term aligns to word starts within a name. They split names on the same
  notion of a "word boundary" and ask the same question — does some word start
  with the term — so that logic lives here.
  """

  # Characters a real word can start right after with no preceding space, in
  # the names we search (bird names and location names): hyphen (Wood-Pigeon,
  # yellow-rumped), slash (Kildonan/Transcona, Collared/Oriental Pratincole),
  # opening brackets ((hybrid), [...]), and the opening double quote of a
  # quoted name (Park "Veselka").
  @word_boundary ~r/[\s\-\/(\["]+/

  @doc """
  Splits `text` into words on name word boundaries, dropping empty fragments.
  """
  @spec split_words(String.t()) :: [String.t()]
  def split_words(text) do
    text
    |> String.split(@word_boundary)
    |> Enum.reject(&(&1 == ""))
  end

  @doc """
  True when some word in `text` begins with `term`.

  This is word-prefix matching, not substring-anywhere: "park" matches
  "Central Park" but not "Sparking", and "cr" matches "Great Crested" but not
  "Acrocephalus".
  """
  @spec word_prefix_match?(String.t(), String.t()) :: boolean()
  def word_prefix_match?(text, term) do
    text
    |> split_words()
    |> Enum.any?(&String.starts_with?(&1, term))
  end
end
