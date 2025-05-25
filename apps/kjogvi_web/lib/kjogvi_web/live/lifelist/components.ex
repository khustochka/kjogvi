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
            <.species_link species={lifer.species} />
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

  attr :selected, :any, required: true, doc: "key of the currently selected item"
  attr :id, :string, required: true

  attr :widths, :string,
    default: "w-1/2 sm:w-1/4 md:w-1/5 lg:w-1/6 xl:w-1/7",
    doc: "Default widths for items"

  attr :selector_widths, :string,
    default: "w-1/2 sm:w-1/4 md:w-1/5 lg:w-1/6 xl:w-1/7",
    doc: "Default widths for selector"

  slot :placeholder, required: true, doc: "placeholder text for selector"

  slot :left, required: true do
    attr :href, :string
  end

  slot :item do
    attr :key, :string
    attr :href, :string
    attr :active, :boolean
  end

  def bivalve_select(assigns) do
    ~H"""
    <div id={@id} class="bivalve-select" phx-mounted={JS.hide(to: {:inner, ".bivalve-ul-items"})}>
      <ul class="bivalve-ul-selector flex flex-wrap gap-0 mb-2">
        <.bivalve_li
          :for={left <- @left}
          data-bivalve-left
          selected={is_nil(@selected)}
          widths={@selector_widths}
        >
          <%= if is_nil(@selected) do %>
            <.bivalve_pill_span>
              <em class="not-italic font-bold">{render_slot(left)}</em>
            </.bivalve_pill_span>
          <% else %>
            <.bivalve_pill_link patch={left.href} id={@id}>
              {render_slot(left)}
            </.bivalve_pill_link>
          <% end %>
        </.bivalve_li>

        <.bivalve_li
          data-bivalve-placeholder
          class="relative hover:cursor-pointer pr-4"
          selected={not is_nil(@selected)}
          widths={@selector_widths}
          phx-click={JS.toggle(to: "##{@id} .bivalve-ul-items")}
        >
          <.bivalve_pill_span>
            <%= if is_nil(@selected) do %>
              <span class="text-gray-500">
                {render_slot(@placeholder)}
              </span>
            <% else %>
              <em class="not-italic font-bold">
                {render_slot(@placeholder)}
              </em>
            <% end %>
          </.bivalve_pill_span>
          <span class="hidden">▼</span>
          <.icon name="hero-chevron-down-solid" class="w-4 h-4 absolute right-1 top-3" />
        </.bivalve_li>
      </ul>

      <div class="bivalve-ul-items js-hidden-element">
        <ul class="flex flex-wrap gap-0">
          <.bivalve_li
            :for={item <- @item}
            data-bivalve-item
            selected={item.key == @selected}
            widths={@widths}
          >
            <%= cond do %>
              <% item.key == @selected -> %>
                <.bivalve_pill_span>
                  <em class="not-italic font-bold">{render_slot(item)}</em>
                </.bivalve_pill_span>
              <% Map.get(item, :active) == false -> %>
                <.bivalve_pill_span>
                  <span class="text-gray-500">{render_slot(item)}</span>
                </.bivalve_pill_span>
              <% true -> %>
                <.bivalve_pill_link patch={item.href} id={@id}>
                  {render_slot(item)}
                </.bivalve_pill_link>
            <% end %>
          </.bivalve_li>
        </ul>
      </div>
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :selected, :boolean, default: false
  attr :widths, :string, required: true
  attr :rest, :global
  slot :inner_block

  defp bivalve_li(assigns) do
    ~H"""
    <li
      class={[
        bivalve_li_classes(@widths),
        @class,
        (@selected && "bg-sky-100 text-sky-900 border-sky-400 z-1") || "border-slate-300"
      ]}
      data-bivalve-selected={@selected}
      {@rest}
    >
      {render_slot(@inner_block)}
    </li>
    """
  end

  attr :id, :string, required: true
  attr :patch, :string, required: true
  slot :inner_block

  defp bivalve_pill_link(assigns) do
    ~H"""
    <.link
      patch={@patch}
      class={[bivalve_pill_classes(), bivalve_link_classes()]}
      phx-click={JS.hide(to: "##{@id} .bivalve-ul-items")}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  defp bivalve_pill_span(assigns) do
    ~H"""
    <span class={[bivalve_pill_classes()]}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  defp bivalve_li_classes(widths) do
    [
      "block text-center mb-1 border-1 mb-[-1px] mr-[-1px]",
      widths
    ]
  end

  defp bivalve_pill_classes do
    "block text-center p-2"
  end

  defp bivalve_link_classes do
    "text-sky-600 underline underline-offset-4 decoration-1 decoration-dashed decoration-sky-400"
  end
end
