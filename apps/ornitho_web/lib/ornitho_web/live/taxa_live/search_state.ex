defmodule OrnithoWeb.Live.Taxa.SearchState do
  @moduledoc """
  Structure representing the search state: term and whether search is enabled.
  """
  defstruct enabled: false, term: nil

  @type t :: %__MODULE__{enabled: boolean(), term: nil | String.t()}

  @minimum_search_term_length 3

  def assign_search_term(term) do
    term = normalize_term(term)

    struct(__MODULE__, %{
      term: term,
      enabled: not is_nil(term) and String.length(term) >= @minimum_search_term_length
    })
  end

  defp normalize_term(nil), do: nil

  defp normalize_term(str) when is_binary(str) do
    case String.trim(str) do
      "" -> nil
      string -> string
    end
  end
end
