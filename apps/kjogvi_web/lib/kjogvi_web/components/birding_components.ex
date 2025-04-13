defmodule KjogviWeb.BirdingComponents do
  @moduledoc """
  Components for birding-related elements of the site, e.g. species links etc.
  """

  use Phoenix.Component
  use KjogviWeb, :verified_routes

  alias Ornitho.Schema.Taxon

  def species_link(assigns) do
    ~H"""
    <span class="species_link">
      <strong phx-no-format class="font-normal small-caps text-[0.95rem]">
        <.link
          patch={~p"/species/#{@species}"}
          class="px-1 py-0.5 no-underline bg-lime-200 hover:bg-lime-300"
        ><%= @species.name_en %></.link>
      </strong>
      <i class="whitespace-nowrap text-neutral-500">{@species.name_sci}</i>
    </span>
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
