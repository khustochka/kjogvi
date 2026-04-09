defmodule KjogviWeb.DiaryComponents do
  @moduledoc """
  Component to render a diary (recent additions) list.
  """

  use Phoenix.Component
  use KjogviWeb, :verified_routes

  import KjogviWeb.HeaderComponents
  import KjogviWeb.BirdingComponents
  import KjogviWeb.FormatComponents

  attr :diary_entries, :list, doc: "List of diary entries", required: true

  def diary(assigns) do
    ~H"""
    <section class="mt-12">
      <.h2>Recent additions</.h2>

      <div :if={@diary_entries == []} class="flex gap-2 items-center text-zinc-500 italic">
        No recent additions.
      </div>

      <ol :if={@diary_entries != []} class="list-none">
        <%= for {date, events} <- @diary_entries do %>
          <li class="mb-8">
            <h3 class="text-sm font-semibold uppercase tracking-wide text-stone-400 mb-3">
              <time datetime={Date.to_iso8601(date)}>{format_date(date)}</time>
            </h3>
            <ul class="list-none space-y-2">
              <%= for event <- events do %>
                <li class="flex gap-2 items-baseline">
                  <div class="flex flex-wrap gap-x-1 gap-y-0.5 items-baseline">
                    <span class="text-stone-600 mr-1">
                      {diary_area_label(event)}
                    </span>
                    <%= for {life_obs, i} <- Enum.with_index(event.life_observations) do %>
                      <span phx-no-format><.species_link_name_only
                    phx-no-format
                    species={life_obs.species_page}
                  />{if i <
                          length(event.life_observations) - 1,
                        do: ", ",
                        else: "."}</span>
                    <% end %>
                  </div>
                </li>
              <% end %>
            </ul>
          </li>
        <% end %>
      </ol>
    </section>
    """
  end

  defp diary_area_label(%{area: nil, type: :total} = entry) do
    if length(entry.life_observations) == 1 do
      "New lifer:"
    else
      "Added #{length(entry.life_observations)} lifers:"
    end
  end

  defp diary_area_label(%{area: nil, type: :year, year: year} = entry) do
    if length(entry.life_observations) == 1 do
      "New species for #{year} year list:"
    else
      "Added #{length(entry.life_observations)} species to #{year} year list:"
    end
  end

  defp diary_area_label(%{area: area, type: :total} = entry) do
    if length(entry.life_observations) == 1 do
      "New species for #{area.name_en}:"
    else
      "Added #{length(entry.life_observations)} species for #{area.name_en}:"
    end
  end

  defp diary_area_label(%{area: area, type: :year, year: year} = entry) do
    if length(entry.life_observations) == 1 do
      "New species for #{area.name_en} in #{year}:"
    else
      "Added #{length(entry.life_observations)} species for #{area.name_en} in #{year}:"
    end
  end
end
