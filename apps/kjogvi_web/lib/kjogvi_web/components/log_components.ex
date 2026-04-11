defmodule KjogviWeb.LogComponents do
  @moduledoc """
  Component to render a log (recent additions list).
  """

  use KjogviWeb, :html

  import KjogviWeb.HeaderComponents
  import KjogviWeb.BirdingComponents
  import KjogviWeb.FormatComponents

  attr :log_entries, :list, doc: "List of log entries", required: true
  attr :current_scope, :any, required: true

  def log(assigns) do
    ~H"""
    <section class="mt-12">
      <.h2>Recent additions</.h2>

      <div :if={@log_entries == []} class="flex gap-2 items-center text-zinc-500 italic">
        No recent additions.
      </div>

      <dl :if={@log_entries != []} class="md:grid md:grid-cols-[auto_1fr] md:gap-x-8">
        <%= for {date, entries} <- @log_entries do %>
          <dt class="mb-2 md:mb-0 md:pt-0.5 text-sm font-semibold text-stone-400 md:text-right whitespace-nowrap">
            <time datetime={Date.to_iso8601(date)}>{format_date(date)}</time>
          </dt>
          <dd class="mb-6 md:mb-4">
            <ul class="list-none space-y-2">
              <%= for entry <- entries do %>
                <li class="flex gap-2 items-baseline">
                  <div class="flex flex-wrap gap-x-1 gap-y-0.5 items-baseline">
                    <span class="text-stone-600 mr-1">
                      <.entry_label entry={entry} current_scope={@current_scope} />:
                    </span>
                    <%= for {life_obs, i} <- Enum.with_index(entry.life_observations) do %>
                      <span phx-no-format><.species_link_name_only
                    phx-no-format
                    species={life_obs.species_page}
                  />{if i <
                          length(entry.life_observations) - 1,
                        do: ", ",
                        else: ""}</span>
                    <% end %>
                  </div>
                </li>
              <% end %>
            </ul>
          </dd>
        <% end %>
      </dl>
    </section>
    """
  end

  # Label for a log entry. Renders the appropriate phrasing depending on
  # whether this entry covers a single species or many, and whether it has
  # any secondary covered areas (e.g. a world lifer that is also a new
  # species for Manitoba). list_totals are rendered as links to the
  # corresponding lifelist page anchors.
  attr :entry, :any, required: true
  attr :current_scope, :any, required: true

  defp entry_label(%{entry: %{life_observations: obs}} = assigns)
       when length(obs) == 1 do
    ~H"""
    <span phx-no-format>{singular_prefix(@entry)} <.total_badge
      scope={@current_scope}
      filter={primary_filter(@entry)}
      total={@entry.list_total}
    /></span><span
      :for={{area, total} <- @entry.covered_areas}
      phx-no-format
    >, new species in {area.name_en} <.total_badge
      scope={@current_scope}
      filter={[location: area]}
      total={total}
    /></span>
    """
  end

  defp entry_label(assigns) do
    ~H"""
    <span phx-no-format>{plural_prefix(@entry)} <.total_badge
      scope={@current_scope}
      filter={primary_filter(@entry)}
      total={@entry.list_total}
    /></span><span
      :for={{area, total} <- @entry.covered_areas}
      phx-no-format
    >, new species in {area.name_en} <.total_badge
      scope={@current_scope}
      filter={[location: area]}
      total={total}
    /></span>
    """
  end

  attr :scope, :any, required: true
  attr :filter, :list, required: true
  attr :total, :integer, required: true

  defp total_badge(assigns) do
    ~H"""
    <span phx-no-format class="text-stone-400 text-sm">(<.link
      phx-no-format
      href={lifelist_path(@scope, @filter) <> "#lifer-#{@total}"}
      class="underline"
    >{@total}</.link>)</span>
    """
  end

  # Phrasing for a single-species primary entry. Uses "in" for areas and
  # "for" for years, consistently across singular and plural forms.
  defp singular_prefix(%{area: nil, type: :life}), do: "New lifer"
  defp singular_prefix(%{area: area, type: :life}), do: "New species in #{area.name_en}"
  defp singular_prefix(%{area: nil, type: :year, year: year}), do: "New species for #{year}"

  defp singular_prefix(%{area: area, type: :year, year: year}),
    do: "New species in #{area.name_en} for #{year}"

  # Phrasing for a multi-species entry with no secondary covered areas.
  # Parallels singular_prefix/1: "in" for areas, "for" for years.
  defp plural_prefix(%{area: nil, type: :life, life_observations: obs}) do
    "Added #{length(obs)} new lifers"
  end

  defp plural_prefix(%{area: area, type: :life, life_observations: obs}) do
    "Added #{length(obs)} new species in #{area.name_en}"
  end

  defp plural_prefix(%{area: nil, type: :year, year: year, life_observations: obs}) do
    "Added #{length(obs)} new species for #{year}"
  end

  defp plural_prefix(%{area: area, type: :year, year: year, life_observations: obs}) do
    "Added #{length(obs)} new species in #{area.name_en} for #{year}"
  end

  defp primary_filter(%{area: area, type: :life}), do: [location: area]
  defp primary_filter(%{area: area, type: :year, year: year}), do: [location: area, year: year]
end
