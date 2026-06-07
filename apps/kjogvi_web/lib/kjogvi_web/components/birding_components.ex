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

  attr :on_delete, :string,
    default: nil,
    doc: "phx event name to trigger card deletion; passed through to each panel"

  def card_list(assigns) do
    ~H"""
    <ul id={@id} role="list" class="flex flex-col gap-3">
      <.card_panel :for={card <- @cards} card={card} on_delete={@on_delete} />
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

  attr :on_delete, :string,
    default: nil,
    doc: "phx event name to trigger card deletion; when set, a delete control is rendered"

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
          class="font-semibold text-stone-900 underline decoration-forest-500 decoration-2 underline-offset-2 hover:decoration-forest-700"
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
          <.delete_card_button :if={@on_delete} card={@card} on_delete={@on_delete} />
        </div>
      </div>

      <.card_observations :if={card_has_loaded_observations?(@card)} card={@card} />
    </li>
    """
  end

  @doc """
  Renders a card's observations as a compact bottom section of its panel.

  Expects `@card.observations` to be a loaded list, each observation carrying a
  preloaded `:taxon` (and optionally `:species`). When the list is empty, a
  muted "No observations" line is shown instead.
  """
  attr :card, :map, required: true

  def card_observations(assigns) do
    ~H"""
    <div class="mt-3 -mx-2.5 -mb-2.5 rounded-b-lg border-t-2 border-stone-200 bg-stone-50 px-3 py-2.5">
      <p :if={@card.observations == []} class="text-sm text-stone-400">
        No observations.
      </p>
      <ul
        :if={@card.observations != []}
        role="list"
        class="flex flex-col divide-y divide-stone-200/70 text-[0.95rem]"
      >
        <li
          :for={obs <- @card.observations}
          id={"card-#{@card.id}-obs-#{obs.id}"}
          class="flex items-baseline gap-x-2 py-1 first:pt-0 last:pb-0"
        >
          <span :if={present?(obs.quantity)} class="shrink-0 tabular-nums text-stone-500">
            {obs.quantity}
          </span>
          <span class="min-w-0 break-words sm:truncate">
            <.observation_taxon_name obs={obs} />
          </span>
          <span
            :if={obs.voice}
            title="Heard only"
            class="inline-flex shrink-0 items-center rounded-full bg-teal-100 p-1 text-teal-700 ring-1 ring-inset ring-teal-300"
          >
            <.icon name="hero-musical-note-solid" class="h-4 w-4" />
            <span class="sr-only">heard only</span>
          </span>
          <span
            :if={obs.hidden}
            title="Hidden"
            class="inline-flex shrink-0 items-center rounded-full bg-red-100 p-1 text-red-600 ring-1 ring-inset ring-red-300"
          >
            <.icon name="hero-eye-slash-solid" class="h-4 w-4" />
            <span class="sr-only">hidden</span>
          </span>
          <span class="ml-auto shrink-0 pl-2 font-mono text-xs text-stone-400" title="Observation ID">
            #{obs.id}
          </span>
        </li>
      </ul>
    </div>
    """
  end

  attr :obs, :map, required: true

  defp observation_taxon_name(%{obs: %{taxon: nil}} = assigns) do
    ~H"""
    <span class="font-mono text-sm text-stone-400" title="Undefined taxon">
      {@obs.taxon_key}
    </span>
    """
  end

  defp observation_taxon_name(assigns) do
    ~H"""
    <span>
      <span class="font-medium text-stone-800">{@obs.taxon.name_en}</span>
      <i class="text-stone-400">{@obs.taxon.name_sci}</i>
    </span>
    """
  end

  # Observations are an Ecto association: unloaded it is a %NotLoaded{}, loaded
  # it is a list. Only render the section when an actual list is present.
  defp card_has_loaded_observations?(%{observations: obs}) when is_list(obs), do: true
  defp card_has_loaded_observations?(_card), do: false

  @doc """
  Renders the card delete control.

  When the card can be deleted, renders a clearly red-outlined trash button that
  triggers the `on_delete` event (with a confirmation). When it cannot (it still
  has observations), renders an inert, plainly-disabled placeholder carrying none
  of the action wiring (`phx-click`, `data-confirm`, …).
  """
  attr :card, :map, required: true
  attr :on_delete, :string, required: true

  def delete_card_button(%{card: card} = assigns) do
    assigns = assign(assigns, :deletable, card_deletable?(card))

    ~H"""
    <button
      :if={@deletable}
      type="button"
      id={"delete-card-#{@card.id}"}
      phx-click={@on_delete}
      phx-value-id={@card.id}
      data-confirm={"Delete card ##{@card.id}? This cannot be undone."}
      title="Delete card"
      aria-label={"Delete card ##{@card.id}"}
      class="inline-flex cursor-pointer items-center rounded-md border border-red-400 bg-white p-1 text-red-600 hover:border-red-500 hover:bg-red-50 hover:text-red-700"
    >
      <.icon name="hero-trash" class="h-3.5 w-3.5" />
    </button>
    <span
      :if={!@deletable}
      id={"delete-card-#{@card.id}"}
      title="Cards with observations cannot be deleted"
      class="inline-flex cursor-not-allowed items-center rounded-md border border-stone-200 bg-white p-1 text-stone-300"
    >
      <.icon name="hero-trash" class="h-3.5 w-3.5" />
    </span>
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

  defp card_deletable?(card), do: Kjogvi.Birding.card_deletable?(card)

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
