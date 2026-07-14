defmodule Kjogvi.Util.String do
  @moduledoc """
  String helpers for accent-insensitive search and matching.

  Two transforms with deliberately different scope:

  - `strip_diacritics/1` — the narrow one, for **sort/search** keys. Folds a
    string to its unaccented Latin form, mirroring Postgres `unaccent()`; case
    and punctuation (dashes, slashes, brackets) are left intact so
    word-boundary ranking still works (see `Kjogvi.Search.WordMatch`).
  - `normalize_for_match/1` — the aggressive one, for **equality/grouping**
    keys. Also downcases and collapses every punctuation/whitespace run to a
    single space, so independently written variants like "Rhône–Alpes" and
    "Rhone-Alpes" compare equal.
  """

  # Latin letters that NFD does *not* decompose into base + combining mark, so
  # the `\p{Mn}` strip leaves them intact. Postgres `unaccent()` folds all of
  # these (values below match its output exactly), so we fold them too to stay a
  # faithful mirror of the DB filter; it also lets an eBird name match its ISO
  # counterpart, since eBird flattens these letters while ISO keeps them (e.g.
  # Polish "Łódzkie" → eBird "Lodzkie"). Both cases are listed; `İ`/dotted forms
  # are handled by the NFD strip and need no entry here.
  @special_letters %{
    "ł" => "l",
    "Ł" => "L",
    "ø" => "o",
    "Ø" => "O",
    "đ" => "d",
    "Đ" => "D",
    "ð" => "d",
    "Ð" => "D",
    "þ" => "th",
    "Þ" => "TH",
    "ß" => "ss",
    "ẞ" => "SS",
    "ı" => "i",
    "æ" => "ae",
    "Æ" => "AE",
    "œ" => "oe",
    "Œ" => "OE",
    "ħ" => "h",
    "Ħ" => "H",
    "ŋ" => "n",
    "Ŋ" => "N",
    "ĸ" => "q"
  }
  @special_letter_keys Map.keys(@special_letters)

  @doc """
  Folds a string to its unaccented Latin form, mirroring Postgres `unaccent()`:
  NFD-decompose and drop combining marks, then fold the non-decomposing Latin
  letters (ł, ø, ß, …). Case and punctuation are preserved.
  """
  @spec strip_diacritics(String.t()) :: String.t()
  def strip_diacritics(string) do
    string
    |> String.normalize(:nfd)
    |> String.replace(~r/\p{Mn}/u, "")
    |> String.replace(@special_letter_keys, &Map.fetch!(@special_letters, &1))
  end

  @doc """
  Canonical match key for equality/grouping: `strip_diacritics/1`, downcased,
  with punctuation/whitespace runs — dashes included — collapsed to single
  spaces and trimmed. `nil` becomes `""` (which never matches).
  """
  @spec normalize_for_match(String.t() | nil) :: String.t()
  def normalize_for_match(nil), do: ""

  def normalize_for_match(string) do
    string
    |> strip_diacritics()
    |> String.downcase()
    |> String.replace(~r/[^\p{L}\p{N}]+/u, " ")
    |> String.trim()
  end
end
