defmodule KjogviWeb.Live.Lifelist.Components do
  @moduledoc false

  use KjogviWeb, :html

  alias Kjogvi.Geo

  attr :id, :string, required: true
  attr :show_private_details, :boolean, default: false
  attr :lifelist, :list, required: true
  attr :location_field, :atom, required: true

  def lifers_list(assigns) do
    ~H"""
    <div class="md:py-1 hidden md:grid md:grid-cols-[3.5ch_2fr_auto_3fr] md:gap-x-6 md:gap-y-1 md:items-center text-gray-400 text-sm">
      <span class="col-start-3 col-end-4 justify-self-center">Date</span>
      <span class="col-start-4 col-end-5 justify-self-center">Location</span>
    </div>
    <ol
      id={@id}
      class="lifers-list border-t-1 border-gray-200"
      style={"--lifersTotal:#{@lifelist.total + 1};"}
    >
      <%= for {lifer, i} <- Enum.with_index(@lifelist.list) do %>
        <%!-- ch is the width of a "0" --%>
        <li
          value={@lifelist.total - i}
          class="py-6 border-b-1 border-gray-200 grid grid-cols-[3.5ch_2fr_auto_3fr] gap-x-2 md:gap-x-6 gap-y-1 items-top md:items-center"
        >
          <span class="counter text-gray-500 col-span-1 align-right justify-self-end"></span>
          <div class="mb-1 col-span-3 md:col-span-1">
            <.species_link species={lifer.species_page} />
          </div>
          <div class="col-start-2 col-end-5 md:col-span-1 align-left justify-self-end text-right text-sm text-zinc-600">
            <time time={lifer.observ_date}>
              {format_date(lifer.observ_date)}
            </time>
            <.link :if={@show_private_details} navigate={~p"/my/cards/#{lifer.card_id}"}>
              <.icon name="hero-clipboard-document-list" class="w-[18px] text-gray-400" />
            </.link>
          </div>
          <div class="col-start-2 col-end-5 md:col-span-1 justify-self-end text-right italic text-[0.93rem] text-gray-700">
            <%= with location <- get_in(lifer, [Access.key!(@location_field)]) do %>
              <%!-- Do not break the line below --%>
              <span class="after:content-['_·']">{Geo.Location.name_local_part(location)}</span><span class="sr-only">, </span>
              <%= with country when not is_nil(country) <- location.cached_country do %>
                <span class="font-medium whitespace-nowrap">
                  {Geo.Location.name_administrative_part(location)}
                </span>
                <span class="flag">{Kjogvi.Geo.Location.to_flag_emoji(country)}</span>
              <% end %>
            <% end %>
          </div>
        </li>
      <% end %>
    </ol>
    """
  end

  attr :selected, :boolean, default: false
  attr :active, :boolean, default: true
  attr :href, :string, required: true
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def filter_pill(%{selected: true} = assigns) do
    ~H"""
    <li class={@class}>
      <span class="block text-center px-2 py-1.5 text-sm font-bold text-sky-900 bg-sky-100 border border-sky-300 rounded">
        {render_slot(@inner_block)}
      </span>
    </li>
    """
  end

  def filter_pill(%{active: false} = assigns) do
    ~H"""
    <li class={@class}>
      <span class="block text-center px-2 py-1.5 text-sm text-gray-500 border border-slate-200 rounded">
        {render_slot(@inner_block)}
      </span>
    </li>
    """
  end

  def filter_pill(assigns) do
    ~H"""
    <li class={@class}>
      <.link
        patch={@href}
        class="block text-center px-2 py-1.5 text-sm text-sky-600 bg-white border border-slate-200 rounded hover:bg-sky-50"
      >
        {render_slot(@inner_block)}
      </.link>
    </li>
    """
  end
end
