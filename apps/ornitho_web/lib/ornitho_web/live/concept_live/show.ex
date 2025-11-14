defmodule OrnithoWeb.Live.Concept.Show do
  @moduledoc false

  use OrnithoWeb, :live_view

  import OrnithoWeb.BreadcrumbsComponents

  @impl true
  def mount(%{}, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    taxa =
      Ornitho.Finder.Taxon.by_concept_id(id)
      |> Ornitho.Finder.Taxon.with_book()
      |> Ornitho.Finder.Taxon.with_parent_species()

    {:noreply,
     socket
     |> assign(:taxa, taxa)
     |> assign(:concept_id, id)
     |> assign(:page_title, "Taxon concept id: #{id}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.breadcrumbs>
      <:crumb><b><.link href={OrnithoWeb.LinkHelper.root_path(@socket)}>Taxonomy</.link></b></:crumb>
      <:crumb>
        <b>
          Concepts
        </b>
      </:crumb>
      <:crumb>{@concept_id}</:crumb>
    </.breadcrumbs>

    <.header>
      Taxon concept {@concept_id}
    </.header>

    <div :if={@taxa != []} class="mt-6">
      <h2>Corresponding taxa</h2>
      <OrnithoWeb.Live.Taxa.Table.render
        taxa={@taxa}
        mixed_book_view={true}
        skip_parent_species={false}
        link_builder={&OrnithoWeb.LinkHelper.path(@socket, &1)}
      />
    </div>
    """
  end
end
