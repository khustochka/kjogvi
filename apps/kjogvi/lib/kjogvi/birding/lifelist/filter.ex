defmodule Kjogvi.Birding.Lifelist.Filter do
  @moduledoc """
  Lifelist filtering parameters.

  With a `book`, the lifelist is of recorded taxa, matched into that taxonomy
  book, rather than of species pages (see `Kjogvi.Birding.TaxaLifelist`);
  `species_only` then rolls those taxa up to species.
  """

  alias Kjogvi.Geo

  @type t() :: %__MODULE__{}

  @schema [
    year: [
      type: {:or, [:integer, nil]},
      default: nil
    ],
    month: [
      type: {:or, [{:in, 1..12}, nil]},
      default: nil
    ],
    location: [
      type: {:or, [:string, {:struct, Geo.Location}, nil]},
      default: nil
    ],
    motorless: [
      type: :boolean,
      default: false
    ],
    exclude_heard_only: [
      type: :boolean,
      default: false
    ],
    sort: [
      type: {:in, [:date, :taxonomy]},
      default: :date
    ],
    book: [
      type: {:or, [{:struct, Ornitho.Schema.Book}, nil]},
      default: nil
    ],
    species_only: [
      type: :boolean,
      default: false
    ]
  ]

  use Kjogvi.Filter, schema: @schema
end
