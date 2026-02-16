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
      <.link
        phx-no-format
        patch={~p"/species/#{@species}"}
        class="text-[1.05rem] font-semibold text-forest-500 underline decoration-forest-200 hover:decoration-forest-400 underline-offset-2"
      ><%= @species.name_en %></.link>
      <i class="whitespace-nowrap text-[0.93rem] text-stone-400">{@species.name_sci}</i>
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
