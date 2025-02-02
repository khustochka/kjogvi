defmodule Kjogvi.Birding.Lifelist.Filter do
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
    ],
    motorless: [
      type: :boolean,
      default: false
    ],
    exclude_heard_only: [
      type: :boolean,
      default: false
    ],
    include_hidden: [
      type: :boolean,
      default: false
    ]
  ]

  defstruct Keyword.keys(@schema)

  def discombo(opts) do
    case NimbleOptions.validate(opts, @schema) do
      {:ok, result} ->
        {:ok, struct!(__MODULE__, result)}

      err ->
        err
    end
  end

  def discombo!(opts) do
    opts |> NimbleOptions.validate!(@schema) |> then(&struct!(__MODULE__, &1))
  end
end
