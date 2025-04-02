defmodule KjogviWeb.Live.Lifelist.Components do
  @moduledoc false

  use KjogviWeb, :html

  alias Kjogvi.Geo

  attr :id, :string, required: true
  attr :show_private_details, :boolean, default: false
  attr :lifelist, :list, required: true
  attr :location_field, :atom, required: true

  def lifers_table(assigns) do
    ~H"""
    <table id={@id} class="mt-11 w-full">
      <thead class="text-sm text-left leading-snug text-zinc-500">
        <tr>
          <th class="p-0 pr-6 pb-4 font-normal"></th>
          <th class="p-0 pr-6 pb-4 font-normal">Species</th>
          <th class="p-0 pr-6 pb-4 font-normal text-center">Date</th>
          <th class="p-0 pr-6 pb-4 font-normal">Location</th>
          <th :if={@show_private_details} class="p-0 pr-6 pb-4 font-normal text-center">Card</th>
        </tr>
      </thead>
      <tbody class="divide-y divide-zinc-100 border-t border-zinc-200 leading-snug text-zinc-700">
        <%= for {lifer, i} <- Enum.with_index(@lifelist.list) do %>
          <tr>
            <td class="p-0 py-4 pr-6 text-right">{@lifelist.total - i}.</td>
            <td class="p-0 py-4 pr-6">
              <.species_link species={lifer.species} />
              <%!-- <strong class="font-bold">{lifer.species.name_en}</strong>
              <i class="whitespace-nowrap">{lifer.species.name_sci}</i> --%>
            </td>
            <td class="p-0 py-4 pr-6 text-center whitespace-nowrap">
              {format_observation_date(lifer.observ_date)}
            </td>
            <td class="p-0 py-4 pr-6">
              <%= with location <- get_in(lifer, [Access.key!(@location_field)]) do %>
                {Geo.Location.name_local_part(location)} ·
                <%= with country when not is_nil(country) <- location.country do %>
                  <span class="font-semibold whitespace-nowrap">
                    {Geo.Location.name_administrative_part(location)}
                  </span>
                <% end %>
              <% end %>
            </td>
            <td :if={@show_private_details} class="p-0 py-4 pr-6 text-center">
              <.link navigate={~p"/my/cards/#{lifer.card_id}"}>
                <.icon name="hero-clipboard-document-list" class="w-[18px]" />
              </.link>
            </td>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end
end
