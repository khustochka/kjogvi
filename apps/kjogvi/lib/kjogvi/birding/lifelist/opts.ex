defmodule Kjogvi.Birding.Lifelist.Opts do
  @moduledoc """
  Lifelist filtering parameters.
  """

  alias Kjogvi.Geo

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
    ]
    # public_view: [
    #   type: :boolean,
    #   default: false
    # ]
  ]

  defstruct Keyword.keys(@schema)

  def discombo(opts) do
    opts |> NimbleOptions.validate!(@schema) |> then(&struct!(__MODULE__, &1))
  end
end
