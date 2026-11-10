defmodule KjogviWeb.Live.My.Taxa.Show do
  @moduledoc """
  A taxon from any taxonomy book, with a paginated list of the user's
  observations recorded with exactly that taxon.
  """

  use KjogviWeb, :live_view

  alias Kjogvi.Birding
  alias Kjogvi.Geo
  alias Ornitho.Schema.Book
  alias Ornitho.Schema.Taxon

  @observations_per_page 50

  @impl true
  def mount(%{"slug" => slug, "version" => version, "code" => code}, _session, socket) do
    book = Ornitho.Finder.Book.by_signature(slug, version) || raise KjogviWeb.NotFoundError

    # `my_taxon_link/1` builds the link from the taxon's book.
    taxon =
      (Ornitho.Finder.Taxon.by_code(book, code) || raise(KjogviWeb.NotFoundError))
      |> Ornitho.Finder.Taxon.with_parent_species()
      |> Taxon.put_book(book)

    user = socket.assigns.current_scope.current_user

    {
      :ok,
      socket
      |> assign(:page_title, "#{taxon.name_en} · #{book.name}")
      |> assign(:book, book)
      |> assign(:taxon, taxon)
      |> assign(:first_record_id, Birding.first_taxon_observation_id(user, Taxon.key(taxon)))
    }
  end

  @impl true
  def handle_params(params, _url, %{assigns: assigns} = socket) do
    page = page_number(params)

    {observations, meta} =
      Birding.taxon_observations(
        assigns.current_scope.current_user,
        Taxon.key(assigns.taxon),
        %{page: page, page_size: @observations_per_page}
      )

    {:noreply, assign(socket, observations: observations, meta: meta)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.h1 class="mb-0!">
      {@taxon.name_en}
    </.h1>
    <p id="taxon-name-sci" class="mt-1 text-lg text-stone-600">
      <i>{@taxon.name_sci}</i>
      <.taxon_category taxon={@taxon} class="text-sm text-stone-500" />
    </p>

    <dl id="taxon-details" class="mt-4 grid grid-cols-[auto_1fr] gap-x-4 gap-y-1 text-sm">
      <dt class="text-stone-500">Taxonomy</dt>
      <dd>
        <b class="font-semibold">{@book.name}</b> ({Book.signature(@book)})
      </dd>
      <dt :if={@taxon.order || @taxon.family} class="text-stone-500">Order / family</dt>
      <dd :if={@taxon.order || @taxon.family}>{@taxon.order} / {@taxon.family}</dd>
      <dt :if={@taxon.parent_species} class="text-stone-500">Species</dt>
      <dd :if={@taxon.parent_species} id="taxon-parent-species">
        <.my_taxon_link taxon={@taxon.parent_species} />
      </dd>
    </dl>

    <.h2 class="mt-8">
      My observations <span class="text-stone-400 font-normal">({@meta.total_count})</span>
    </.h2>

    <p :if={@observations == []} id="taxon-no-observations" class="text-stone-600">
      You haven't recorded this taxon.
    </p>

    <.pagination
      id="taxon-observations-pagination-top"
      meta={@meta}
      path={&my_taxon_path(@taxon, &1)}
      label="Pagination (top)"
      class="mb-2"
      anchor="taxon-observations-pagination-top"
    />

    <ul :if={@observations != []} id="taxon-observations" class="border-t border-stone-200">
      <li
        :for={observation <- @observations}
        id={"observation-#{observation.id}"}
        class="py-3 border-b border-stone-100 flex flex-wrap items-baseline gap-x-4 gap-y-1"
      >
        <.link
          navigate={~p"/my/checklists/#{observation.checklist_id}"}
          class="font-semibold text-forest-700 underline hover:text-forest-900 tabular-nums"
        >{format_date(observation.checklist.observ_date)}</.link>
        <span class="text-stone-600">
          {Geo.Location.long_name(:private, observation.checklist.location)}
        </span>
        <span :if={observation.quantity} class="text-sm text-stone-500">
          × {observation.quantity}
        </span>
        <span :if={observation.voice or observation.hidden} class="inline-flex gap-1">
          <.observation_flags obs={observation} />
        </span>
        <ul class="flex flex-wrap gap-1.5 text-xs" aria-label="Notes">
          <li
            :if={observation.id == @first_record_id}
            class="px-1.5 py-0.5 rounded bg-forest-100 text-forest-800 font-semibold"
          >
            First record
          </li>
          <li
            :if={observation.unreported}
            class="px-1.5 py-0.5 rounded bg-stone-100 text-stone-600"
          >
            Not counted
          </li>
        </ul>
      </li>
    </ul>

    <.pagination
      id="taxon-observations-pagination"
      meta={@meta}
      path={&my_taxon_path(@taxon, &1)}
      anchor="taxon-observations-pagination-top"
    />
    """
  end
end
