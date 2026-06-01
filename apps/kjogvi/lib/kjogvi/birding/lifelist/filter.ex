defmodule Kjogvi.Birding.Lifelist.Filter do
  @moduledoc """
  Lifelist filtering parameters.
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
    ]
  ]

  use Kjogvi.Filter, schema: @schema
end
