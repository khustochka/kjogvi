defmodule Kjogvi.Geo.Location.Filter do
  @moduledoc """
  Purpose-driven refinement of a location query.

  Unlike the visibility scope (whose locations a user may see at all), the filter
  captures *what subset is relevant* for a given affordance — e.g. the card form's
  location picker excludes `special` locations, which a card may never reference
  directly.

  Built either as a bare `%Filter{}` (blank, no-op) or via a named constructor
  such as `for_card_input/0`. Applied to a query by `Location.Query.apply_filter/2`.
  """

  @schema [
    exclude_specials: [
      type: :boolean,
      default: false
    ]
  ]

  use Kjogvi.Filter, schema: @schema

  @type t() :: %__MODULE__{}

  @doc """
  Filter for the card add/edit location picker: hides `special` locations, since a
  card's location must be a concrete hierarchy location.
  """
  def for_card_input do
    %__MODULE__{exclude_specials: true}
  end
end
