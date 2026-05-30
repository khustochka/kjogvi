defmodule KjogviWeb.BirdingComponents do
  @moduledoc """
  Components for birding-related elements of the site, e.g. species links etc.
  """

  use Phoenix.Component
  use KjogviWeb, :verified_routes

  import KjogviWeb.IconComponents
  import KjogviWeb.FormatComponents
  import Kjogvi.Util.Presence

  alias Kjogvi.Geo
  alias Kjogvi.Pages.Species
  alias Ornitho.Schema.Taxon

  @ebird_checklist_base "https://ebird.org/checklist/"

  @effort_labels %{
    "INCIDENTAL" => "Incidental",
    "STATIONARY" => "Stationary",
    "TRAVEL" => "Traveling",
    "AREA" => "Area",
    "HISTORICAL" => "Historical"
  }

  @effort_badge_classes %{
    "INCIDENTAL" => "bg-stone-100 text-stone-600 ring-stone-200",
    "STATIONARY" => "bg-sky-100 text-sky-800 ring-sky-200",
    "TRAVEL" => "bg-forest-100 text-forest-800 ring-forest-200",
    "AREA" => "bg-amber-100 text-amber-800 ring-amber-200",
    "HISTORICAL" => "bg-violet-100 text-violet-800 ring-violet-200"
  }

  @doc """
  Renders a list of cards as full-width panels.

  Each card is rendered with `card_panel/1` inside a semantic `<ul>`/`<li>`
  structure. Use this anywhere cards need to be listed.
  """
  attr :id, :string, required: true
  attr :cards, :list, required: true

  def card_list(assigns) do
    ~H"""
    <ul id={@id} role="list" class="flex flex-col gap-3">
      <.card_panel :for={card <- @cards} card={card} />
    </ul>
    """
  end

  @doc """
  Renders a single card as a panel (`<li>`).

  Shows the card date and location prominently, an inline list of effort-related
  metadata, and highlighted counts of countable species, taxa and observations.
  Provides links to view, edit and (when present) the eBird checklist.
  """
  attr :card, :map, required: true

  def card_panel(assigns) do
    ~H"""
    <li
      id={"card-#{@card.id}"}
      class="group rounded-lg border border-stone-200 bg-white px-2.5 py-2.5 shadow-sm transition hover:shadow"
    >
      <div class="flex flex-wrap items-center gap-x-3 gap-y-1.5 text-[1.05rem]">
        <%!-- Date + location --%>
        <.link
          navigate={~p"/my/cards/#{@card.id}"}
          class="font-semibold text-stone-900 underline decoration-stone-200 decoration-2 underline-offset-2 hover:decoration-forest-500"
        >
          {format_date(@card.observ_date)}
        </.link>
        <.link
          navigate={~p"/my/cards/#{@card.id}"}
          class="min-w-0 flex-1 truncate text-stone-600 no-underline hover:text-stone-900"
        >
          {Geo.Location.long_name(@card.location)}
        </.link>

        <%!-- Counts --%>
        <ul class="flex shrink-0 items-baseline gap-2.5 tabular-nums">
          <li :if={not is_nil(@card.species_count)} title="Countable species">
            <span class="text-lg font-bold text-forest-700">{@card.species_count}</span>
            <span class="text-xs text-stone-500">sp.</span>
            <span class="sr-only">countable species</span>
          </li>
          <li :if={not is_nil(@card.taxa_count)} title="Distinct taxa" class="text-stone-600">
            <span class="font-semibold">{@card.taxa_count}</span>
            <span class="text-xs text-stone-500">taxa</span>
          </li>
          <li
            :if={not is_nil(@card.observation_count)}
            title="Observations"
            class="text-stone-600"
          >
            <span class="font-semibold">{@card.observation_count}</span>
            <span class="text-xs text-stone-500">obs</span>
          </li>
        </ul>
      </div>

      <div class="mt-2.5 flex flex-wrap items-center gap-x-3 gap-y-1 text-[0.95rem] text-stone-600">
        <%!-- Effort metadata --%>
        <ul class="flex flex-1 flex-wrap items-center gap-x-3 gap-y-1">
          <li>
            <.link
              navigate={~p"/my/cards/#{@card.id}"}
              class="font-mono text-sm text-stone-400 no-underline hover:text-stone-600"
              title="Card ID"
            >
              #{@card.id}
            </.link>
          </li>
          <li title="Effort type">
            <.effort_badge effort_type={@card.effort_type} class="text-sm" />
          </li>
          <li :if={@card.start_time} title="Start time" class="tabular-nums">
            <span class="sr-only">Start time:</span>
            {format_time(@card.start_time)}
          </li>
          <li :if={@card.duration_minutes} title="Duration" class="tabular-nums">
            <.icon name="hero-clock" class="h-3.5 w-3.5 -mt-0.5 inline-block text-stone-400" />
            <span class="sr-only">Duration:</span>
            {format_duration(@card.duration_minutes)}
          </li>
          <li :if={@card.distance_kms} title="Distance" class="tabular-nums">
            <.icon
              name="hero-arrows-right-left"
              class="h-3.5 w-3.5 -mt-0.5 inline-block text-stone-400"
            />
            <span class="sr-only">Distance:</span>
            {format_number(@card.distance_kms)} km
          </li>
          <li :if={@card.area_acres} title="Area" class="tabular-nums">
            <.icon
              name="hero-arrows-pointing-out"
              class="h-3.5 w-3.5 -mt-0.5 inline-block text-stone-400"
            />
            <span class="sr-only">Area:</span>
            {format_number(@card.area_acres)} acres
          </li>
          <li :if={present?(@card.observers)} title="Observers">
            <.icon name="hero-users" class="h-3.5 w-3.5 -mt-0.5 inline-block text-stone-400" />
            <span class="sr-only">Observers:</span>
            {@card.observers}
          </li>
          <li :if={@card.motorless} title="Motorless">
            <span class="inline-flex items-center gap-1 rounded-md bg-forest-50 px-1.5 py-0.5 text-sm font-medium text-forest-600">
              <.icon name="bicycle" class="h-4 w-4" /> Motorless
            </span>
          </li>
        </ul>

        <%!-- Actions --%>
        <div class="flex shrink-0 items-center gap-4">
          <.ebird_link :if={@card.ebird_id} ebird_id={@card.ebird_id} class="text-base" />
          <.link
            navigate={~p"/my/cards/#{@card.id}/edit"}
            class="inline-flex items-center gap-1 rounded-md border border-stone-300 bg-white px-2 py-0.5 text-sm font-medium text-stone-700 no-underline hover:border-forest-400 hover:text-forest-700"
          >
            <.icon name="hero-pencil-square" class="h-3.5 w-3.5" />
            Edit<span class="sr-only"> card #{@card.id}</span>
          </.link>
        </div>
      </div>
    </li>
    """
  end

  @doc """
  Renders the effort type of a card as a coloured badge.
  """
  attr :effort_type, :string, required: true
  attr :class, :string, default: nil

  def effort_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center rounded-md px-2 py-0.5 font-medium ring-1 ring-inset",
      effort_badge_class(@effort_type),
      @class
    ]}>
      {effort_label(@effort_type)}
    </span>
    """
  end

  @doc """
  Renders a link to a card's eBird checklist (opens in a new tab).
  """
  attr :ebird_id, :string, required: true
  attr :class, :string, default: nil

  def ebird_link(assigns) do
    ~H"""
    <.link
      href={ebird_checklist_url(@ebird_id)}
      target="_blank"
      rel="noopener"
      title="eBird checklist"
      class={[
        "inline-block border-b-2 border-transparent no-underline hover:border-forest-500",
        @class
      ]}
    >
      <.ebird_wordmark /><span class="sr-only"> checklist (opens in new tab)</span>
    </.link>
    """
  end

  @doc """
  Renders the eBird wordmark as text: a green lowercase "e" and a dark "Bird".

  Inherits its size from the surrounding text; pass extra classes via `class`.
  """
  attr :class, :string, default: nil

  def ebird_wordmark(assigns) do
    ~H"""
    <span class={["font-bold tracking-tight", @class]}>
      <span class="text-forest-600">e</span><span class="text-stone-800">Bird</span>
    </span>
    """
  end

  defp ebird_checklist_url(ebird_id) do
    @ebird_checklist_base <> ebird_id
  end

  @doc "Human-readable label for a card's effort type."
  def effort_label(type) do
    Map.get(@effort_labels, type, type)
  end

  defp effort_badge_class(type) do
    Map.get(@effort_badge_classes, type, "bg-stone-100 text-stone-600 ring-stone-200")
  end

  @doc "Formats a duration in minutes as a human-readable string, e.g. `1 h 35 min`."
  def format_duration(minutes) when minutes >= 60 do
    hours = div(minutes, 60)
    rest = rem(minutes, 60)

    if rest == 0 do
      "#{hours} h"
    else
      "#{hours} h #{rest} min"
    end
  end

  def format_duration(minutes), do: "#{minutes} min"

  @doc "Formats a number, dropping a trailing `.0` so whole numbers read cleanly."
  def format_number(number) do
    rounded = Float.round(number * 1.0, 2)

    if rounded == Float.round(rounded, 0) do
      rounded |> trunc() |> Integer.to_string()
    else
      :erlang.float_to_binary(rounded, [:short])
    end
  end

  attr :species, Species, required: true

  def species_link(assigns) do
    ~H"""
    <span class="species_link" phx-no-format>
      <.link
        phx-no-format
        patch={~p"/species/#{@species}"}
        class="text-[1.05rem] font-semibold text-forest-500 underline decoration-forest-200 hover:decoration-forest-500 hover:bg-forest-100 rounded-sm px-1 -mx-1 underline-offset-2 transition"
      ><%= @species.name_en %></.link> <i class="whitespace-nowrap text-[0.93rem] text-stone-400">{@species.name_sci}</i></span>
    """
  end

  attr :species, Species, required: true

  def species_link_name_only(assigns) do
    ~H"""
    <span class="species_link" phx-no-format>
      <.link
        phx-no-format
        patch={~p"/species/#{@species}"}
        class="font-semibold text-forest-500 underline decoration-forest-200 hover:decoration-forest-500 hover:bg-forest-100 rounded-sm px-1 -mx-1 underline-offset-2 transition"
      ><%= @species.name_en %></.link></span>
    """
  end

  attr :key, :string, required: true
  attr :target, :string, default: nil

  def taxon_code_link(assigns) do
    ~H"""
    <.link href={taxon_url(@key)} target={@target} class="font-mono">
      {@key}
    </.link>
    """
  end

  def taxon_url(key) do
    {book, version, slug} = Taxon.dismantle_key(key)

    ~p"/admin/taxonomy/#{book}/#{version}/#{slug}"
  end
end
