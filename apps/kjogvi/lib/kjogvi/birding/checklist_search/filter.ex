defmodule Kjogvi.Birding.ChecklistSearch.Filter do
  @moduledoc """
  Search/filter parameters for the cards index.

  Filters split into two kinds:

    * **checklist-level** — narrow which cards match without looking inside their
      observations: `date`, `location`, `include_subregions`, `unresolved`.
    * **observation-level** — narrow which individual observations match:
      `taxon_key`, `exclude_subspecies`, `voice` (all/seen/heard-only) and
      `hidden`.

  When any observation-level filter is active, a search runs in
  *observation mode*: results are cards carrying only their matching
  observations. Otherwise it runs in *checklist mode*: whole cards, observations
  untouched. `observation_mode?/1` reports which applies.
  """

  alias Kjogvi.Geo

  alias Kjogvi.Util.Presence

  @type voice() :: :all | :seen | :heard_only
  @type t() :: %__MODULE__{}

  @schema [
    # Checklist-level
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
    unresolved: [
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

  # Defines the struct (defaults mirror the schema, so a bare `%Filter{}` is
  # already a valid, blank filter) plus `discombo/1` and `discombo!/1`.
  use Kjogvi.Filter, schema: @schema

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
    is_nil(filter.date) and is_nil(filter.location) and not filter.unresolved and
      not observation_mode?(filter)
  end

  @doc """
  Encodes a filter as a string-keyed map suitable for a URL query string.

  Only non-default fields are emitted, so a blank filter yields `%{}` (a clean
  `/my/cards` URL). The location is encoded as `location_id`; resolving that id
  back into a `Geo.Location` is the caller's job (see `from_params/1`), since it
  requires a database lookup.
  """
  @spec to_params(t()) :: %{optional(String.t()) => String.t()}
  def to_params(%__MODULE__{} = filter) do
    %{}
    |> put_present("date", filter.date && Date.to_iso8601(filter.date))
    |> put_present("location_id", filter.location && to_string(filter.location.id))
    |> put_flag("include_subregions", filter.include_subregions)
    |> put_flag("unresolved", filter.unresolved)
    |> put_present("taxon_key", filter.taxon_key)
    |> put_flag("exclude_subspecies", filter.exclude_subspecies)
    |> put_present("voice", filter.voice != :all && to_string(filter.voice))
    |> put_flag("hidden", filter.hidden)
  end

  @doc """
  Decodes URL query params into a filter and the requested `location_id`.

  Returns `{filter, location_id}`. The filter's `location` is left `nil`: the
  caller resolves `location_id` into a `Geo.Location` and assigns it. Unknown or
  malformed values fall back to the field default, so any params map is safe.
  """
  @spec from_params(map()) :: {t(), String.t() | nil}
  def from_params(params) when is_map(params) do
    filter = %__MODULE__{
      date: parse_date(params["date"]),
      include_subregions: parse_flag(params["include_subregions"]),
      unresolved: parse_flag(params["unresolved"]),
      taxon_key: Presence.presence(params["taxon_key"]),
      exclude_subspecies: parse_flag(params["exclude_subspecies"]),
      voice: parse_voice(params["voice"]),
      hidden: parse_flag(params["hidden"])
    }

    {filter, Presence.presence(params["location_id"])}
  end

  defp put_present(map, _key, nil), do: map
  defp put_present(map, _key, false), do: map
  defp put_present(map, _key, ""), do: map
  defp put_present(map, key, value), do: Map.put(map, key, value)

  defp put_flag(map, _key, false), do: map
  defp put_flag(map, key, true), do: Map.put(map, key, "true")

  defp parse_date(value) when value in [nil, ""], do: nil

  defp parse_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp parse_flag("true"), do: true
  defp parse_flag(_), do: false

  defp parse_voice("seen"), do: :seen
  defp parse_voice("heard_only"), do: :heard_only
  defp parse_voice(_), do: :all
end
