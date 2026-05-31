defmodule Kjogvi.Birding.CardSearch.Filter do
  @moduledoc """
  Search/filter parameters for the cards index.

  Filters split into two kinds:

    * **card-level** — narrow which cards match without looking inside their
      observations: `date`, `location`, `include_subregions`.
    * **observation-level** — narrow which individual observations match:
      `taxon_key`, `exclude_subspecies`, `voice` (all/seen/heard-only) and
      `hidden`.

  When any observation-level filter is active, a search runs in
  *observation mode*: results are cards carrying only their matching
  observations. Otherwise it runs in *card mode*: whole cards, observations
  untouched. `observation_mode?/1` reports which applies.
  """

  alias Kjogvi.Geo

  @type voice() :: :all | :seen | :heard_only
  @type t() :: %__MODULE__{}

  @schema [
    # Card-level
    date: [
      type: {:or, [{:struct, Date}, nil]},
      default: nil
    ],
    location: [
      type: {:or, [{:struct, Geo.Location}, nil]},
      default: nil
    ],
    include_subregions: [
      type: :boolean,
      default: false
    ],
    # Observation-level
    taxon_key: [
      type: {:or, [:string, nil]},
      default: nil
    ],
    exclude_subspecies: [
      type: :boolean,
      default: false
    ],
    voice: [
      type: {:in, [:all, :seen, :heard_only]},
      default: :all
    ],
    hidden: [
      type: :boolean,
      default: false
    ]
  ]

  # Struct defaults mirror the NimbleOptions schema defaults so that a bare
  # `%Filter{}` (built without going through `discombo!/1`) is already a valid,
  # blank filter.
  defstruct Enum.map(@schema, fn {key, opts} -> {key, Keyword.get(opts, :default)} end)

  @doc """
  Builds a filter from a keyword list / map of options, validating types.
  Raises on invalid input.
  """
  def discombo!(opts) do
    opts
    |> Enum.into([])
    |> NimbleOptions.validate!(@schema)
    |> then(&struct!(__MODULE__, &1))
  end

  @doc """
  Builds a filter, returning `{:ok, filter}` or `{:error, error}`.
  """
  def discombo(opts) do
    case opts |> Enum.into([]) |> NimbleOptions.validate(@schema) do
      {:ok, result} -> {:ok, struct!(__MODULE__, result)}
      err -> err
    end
  end

  @doc """
  True when at least one observation-level filter is active, meaning the search
  should return matching observations (grouped under their cards) rather than
  whole cards.
  """
  @spec observation_mode?(t()) :: boolean()
  def observation_mode?(%__MODULE__{} = filter) do
    not is_nil(filter.taxon_key) or
      filter.exclude_subspecies or
      filter.voice != :all or
      filter.hidden
  end

  @doc """
  True when no filter at all is set — i.e. a plain, unfiltered listing.
  """
  @spec blank?(t()) :: boolean()
  def blank?(%__MODULE__{} = filter) do
    is_nil(filter.date) and is_nil(filter.location) and not observation_mode?(filter)
  end
end
