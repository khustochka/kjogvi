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

      <ol :if={@log_entries != []} class="list-none">
        <%= for {date, entries} <- @log_entries do %>
          <li class="mb-8">
            <h3 class="text-sm font-semibold uppercase tracking-wide text-stone-400 mb-3">
              <time datetime={Date.to_iso8601(date)}>{format_date(date)}</time>
            </h3>
            <ul class="list-none space-y-2">
              <%= for entry <- entries do %>
                <li class="flex gap-2 items-baseline">
                  <div class="flex flex-wrap gap-x-1 gap-y-0.5 items-baseline">
                    <span class="text-stone-600 mr-1">
                      {log_entry_label(entry)}
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
                    <span :if={entry.list_total} class="text-stone-400 text-sm">
                      (<.link
                        href={lifelist_path(@current_scope, log_entry_filter(entry)) <> "#lifer-#{entry.list_total}"}
                        class="underline"
                      >{entry.list_total}</.link>)
                    </span>
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

  defp log_entry_filter(%{area: area, type: :total}), do: [location: area]
  defp log_entry_filter(%{area: area, type: :year, year: year}), do: [location: area, year: year]

  defp log_entry_label(%{area: nil, type: :total} = entry) do
    if length(entry.life_observations) == 1 do
      "New lifer:"
    else
      "Added #{length(entry.life_observations)} lifers:"
    end
  end

  defp log_entry_label(%{area: nil, type: :year, year: year} = entry) do
    if length(entry.life_observations) == 1 do
      "New species for #{year} year list:"
    else
      "Added #{length(entry.life_observations)} species to #{year} year list:"
    end
  end

  defp log_entry_label(%{area: area, type: :total} = entry) do
    if length(entry.life_observations) == 1 do
      "New species for #{area.name_en}:"
    else
      "Added #{length(entry.life_observations)} species for #{area.name_en}:"
    end
  end

  defp log_entry_label(%{area: area, type: :year, year: year} = entry) do
    if length(entry.life_observations) == 1 do
      "New species for #{area.name_en} in #{year}:"
    else
      "Added #{length(entry.life_observations)} species for #{area.name_en} in #{year}:"
    end
  end
end
