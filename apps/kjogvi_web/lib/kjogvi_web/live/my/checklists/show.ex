defmodule KjogviWeb.Live.My.Checklists.Show do
  @moduledoc false

  use KjogviWeb, :live_view

  import Kjogvi.Util.Presence

  alias Kjogvi.Birding
  alias Kjogvi.Geo
  alias Ornitho.Schema.Taxon

  @impl true
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
    }
  end

  @impl true
  def handle_params(%{"id" => id}, _url, %{assigns: assigns} = socket) do
    checklist = Birding.fetch_checklist_with_observations(assigns.current_scope.current_user, id)

    {
      :noreply,
      socket
      |> assign(:page_title, "Checklist ##{checklist.id}")
      |> assign(:checklist, checklist)
      |> assign(:counts, counts(checklist.observations))
    }
  end

  @impl true
  def handle_event("delete", _params, %{assigns: %{checklist: checklist}} = socket) do
    case Birding.delete_checklist(checklist) do
      {:ok, _checklist} ->
        {
          :noreply,
          socket
          |> put_flash(:info, "Checklist ##{checklist.id} deleted.")
          |> push_navigate(to: ~p"/my/checklists")
        }

      {:error, :has_observations} ->
        {
          :noreply,
          put_flash(
            socket,
            :error,
            "Checklist ##{checklist.id} has observations and cannot be deleted."
          )
        }
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <nav id="checklist-breadcrumbs" class="text-sm text-stone-500 mb-4">
      <.breadcrumb_link href={~p"/my/checklists"}>Checklists</.breadcrumb_link>
      <span class="mx-1 text-stone-400">/</span>
      <span class="text-stone-700">Checklist #{@checklist.id}</span>
    </nav>

    <%!-- Heading: identity + actions --%>
    <header class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
      <div class="min-w-0">
        <p class="font-mono text-sm text-stone-400">#{@checklist.id}</p>
        <h1 class="mt-0.5 text-3xl font-bold tracking-tight text-stone-600">
          {format_date(@checklist.observ_date)}
        </h1>
        <div class="mt-1 flex flex-wrap items-center gap-x-3 gap-y-1">
          <p class="text-lg text-stone-600">
            {Geo.Location.long_name(:private, @checklist.location)}
          </p>
          <span
            :if={@checklist.import_source}
            id="checklist-import-source"
            class="text-sm text-stone-400"
          >
            Imported from: {Kjogvi.Types.ImportSource.label(@checklist.import_source)}
          </span>
          <span
            :if={not @checklist.resolved}
            id="checklist-unresolved"
            title="This checklist is marked unresolved and may still need amending"
            class="inline-flex items-center gap-1 rounded-md bg-red-50 px-2 py-0.5 text-sm font-medium text-red-700 ring-1 ring-red-200 ring-inset"
          >
            <.icon name="hero-exclamation-triangle" class="h-4 w-4" /> Unresolved
          </span>
          <span
            :if={@checklist.motorless}
            title="Motorless"
            class="inline-flex items-center gap-1 rounded-md bg-forest-50 px-2 py-0.5 text-sm font-medium text-forest-600"
          >
            <.icon name="bicycle" class="h-4 w-4" /> Motorless
          </span>
        </div>
      </div>

      <div class="flex shrink-0 items-center gap-4 sm:mt-6">
        <.action_button navigate={~p"/my/checklists/#{@checklist.id}/edit"} icon="hero-pencil-square">
          Edit
        </.action_button>
        <button
          :if={Birding.checklist_deletable?(@checklist)}
          type="button"
          id="delete-checklist"
          phx-click="delete"
          data-confirm={"Delete checklist ##{@checklist.id}? This cannot be undone."}
          title="Delete checklist"
          class="inline-flex cursor-pointer items-center gap-2 rounded-lg px-4 py-2 text-sm font-semibold text-red-700 ring-1 ring-inset ring-red-300 hover:bg-red-50"
        >
          <.icon name="hero-trash" class="h-4 w-4" /> Delete
        </button>
        <span
          :if={not Birding.checklist_deletable?(@checklist)}
          id="delete-checklist"
          title="Checklists with observations cannot be deleted"
          class="inline-flex cursor-not-allowed items-center gap-2 rounded-lg px-4 py-2 text-sm font-semibold text-stone-400 ring-1 ring-inset ring-stone-200"
        >
          <.icon name="hero-trash" class="h-4 w-4" /> Delete
        </span>
      </div>
    </header>

    <%!-- eBird details --%>
    <section :if={@checklist.ebird_id} id="checklist-ebird-details" class="mt-6">
      <.ebird_panel ebird_id={@checklist.ebird_id} ebird_complete={@checklist.ebird_complete} />
    </section>

    <%!-- Effort (left) + counts (bottom right) --%>
    <div class="mt-6 flex flex-col gap-6 sm:flex-row sm:items-end sm:justify-between">
      <div class="flex min-w-0 flex-wrap items-center gap-x-8 gap-y-3">
        <.effort_badge
          effort_type={@checklist.effort_type}
          effort_name={@checklist.effort_name}
          class="px-4 py-1.5 text-xl"
        />
        <span :if={@checklist.effort_name} class="text-xl text-stone-700" title="Effort name">
          {@checklist.effort_name}
        </span>
        <.ebird_completeness_badge
          :if={!@checklist.ebird_id && not is_nil(@checklist.ebird_complete)}
          ebird_complete={@checklist.ebird_complete}
        />
        <dl class="flex flex-wrap items-center gap-x-8 gap-y-3">
          <.detail :if={@checklist.start_time} label="Start time">
            {format_time(@checklist.start_time)}
          </.detail>
          <.detail :if={@checklist.duration_minutes} label="Duration">
            {format_duration(@checklist.duration_minutes)}
          </.detail>
          <.detail :if={@checklist.distance_kms} label="Distance">
            {format_number(@checklist.distance_kms)} km
          </.detail>
          <.detail :if={@checklist.area_acres} label="Area">
            {format_number(@checklist.area_acres)} acres
          </.detail>
          <.detail :if={present?(@checklist.observers)} label="Observers">
            {@checklist.observers}
          </.detail>
          <.detail :if={present?(@checklist.biotope)} label="Biotope">{@checklist.biotope}</.detail>
          <.detail :if={present?(@checklist.weather)} label="Weather">{@checklist.weather}</.detail>
        </dl>
      </div>

      <dl class="flex shrink-0 items-end gap-6">
        <div>
          <dt class="text-xs font-medium uppercase tracking-wide text-forest-600">Species</dt>
          <dd class="text-5xl font-extrabold leading-none text-forest-600 tabular-nums">
            {@counts.species}
          </dd>
        </div>
        <.count label="Taxa" value={@counts.taxa} class="text-sky-700" />
        <.count label="Obs" value={@counts.observations} class="text-stone-500" />
      </dl>
    </div>

    <%!-- Notes --%>
    <section :if={present?(@checklist.notes)} class="mt-6">
      <.h2 class="mb-3">Notes</.h2>
      <p class="whitespace-pre-line text-stone-700">{@checklist.notes}</p>
    </section>

    <%!-- Observations --%>
    <section class="mt-10">
      <.h2 class="mb-0">Observations</.h2>

      <p :if={Enum.empty?(@checklist.observations)} class="text-stone-500">
        This checklist has no observations.
      </p>
      <div class="-mt-8">
        <.table
          :if={!Enum.empty?(@checklist.observations)}
          id="observation"
          rows={@checklist.observations}
        >
          <:col :let={obs} label="id">{obs.id}</:col>
          <:col :let={obs} label="Quantity">
            {obs.quantity}
            <span :if={obs.hidden} title="Hidden" class="pl-2">
              <.icon name="hero-eye-slash" class="h-4 w-4 text-red-500" />
            </span>
            <span :if={obs.voice} title="Heard only" class="pl-2">
              <.icon name="hero-musical-note" class="h-4 w-4 text-teal-600" />
            </span>
          </:col>
          <:col :let={obs} label="Taxon">
            {present_taxon(Map.take(obs, [:taxon_key, :taxon]))}
            <span
              :if={missing_species_page?(obs)}
              id={"observation-#{obs.id}-no-species-page"}
              title="This taxon counts toward the lifelist but has no species page yet, so it won't appear there. Re-save the checklist to fix it."
              class="mt-1 inline-flex items-center gap-1 rounded-md bg-amber-50 px-2 py-0.5 text-sm font-medium text-amber-700 ring-1 ring-amber-200 ring-inset"
            >
              <.icon name="hero-exclamation-triangle" class="h-4 w-4" /> No species page
            </span>
          </:col>
        </.table>
      </div>
    </section>
    """
  end

  attr :label, :string, required: true
  slot :inner_block, required: true

  defp detail(assigns) do
    ~H"""
    <div>
      <dt class="text-xs font-medium uppercase tracking-wide text-stone-500">{@label}</dt>
      <dd class="mt-0.5 text-lg font-semibold text-stone-900 tabular-nums">
        {render_slot(@inner_block)}
      </dd>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :class, :string, default: nil

  defp count(assigns) do
    ~H"""
    <div>
      <dt class="text-xs font-medium uppercase tracking-wide text-stone-400">{@label}</dt>
      <dd class={["text-2xl font-bold leading-none tabular-nums", @class || "text-stone-800"]}>
        {@value}
      </dd>
    </div>
    """
  end

  def present_taxon(%{taxon: nil} = assigns) do
    ~H"""
    <div class="text-slate-400">
      {@taxon_key}
    </div>
    <.error>
      Undefined taxon!
    </.error>
    """
  end

  def present_taxon(assigns) do
    ~H"""
    <div>
      <.taxon_code_link key={@taxon_key} target="_blank" />
    </div>
    <div>
      <b class="font-semibold">{@taxon.name_en}</b>
      <i>{@taxon.name_sci}</i>
    </div>
    """
  end

  # The taxon resolves to a countable species, but no species page exists for
  # it yet — so this observation is silently excluded from the lifelist.
  defp missing_species_page?(%{taxon: taxon, species: nil}) do
    not is_nil(Taxon.species(taxon))
  end

  defp missing_species_page?(_obs), do: false

  defp counts(observations) do
    %{
      observations: length(observations),
      taxa: observations |> Enum.map(& &1.taxon_key) |> Enum.uniq() |> length(),
      species:
        observations
        |> Enum.reject(& &1.unreported)
        |> Enum.map(& &1.species)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq_by(& &1.id)
        |> length()
    }
  end
end
