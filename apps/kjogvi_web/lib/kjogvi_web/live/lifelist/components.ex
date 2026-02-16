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
    <ol
      id={@id}
      class="lifers-list border-t border-stone-200"
      style={"--lifersTotal:#{@lifelist.total + 1};"}
    >
      <%= for {lifer, i} <- Enum.with_index(@lifelist.list) do %>
        <li
          value={@lifelist.total - i}
          class="py-4 border-b border-stone-100 grid grid-cols-[3.5ch_2fr_auto_3fr] gap-x-2 md:gap-x-6 gap-y-1 items-top md:items-center"
        >
          <span class="counter text-stone-400 text-sm col-span-1 justify-self-end tabular-nums">
          </span>
          <div class="mb-1 col-span-3 md:col-span-1">
            <.species_link species={lifer.species_page} />
          </div>
          <div class="col-start-2 col-end-5 md:col-span-1 justify-self-end text-right text-sm text-stone-500">
            <time time={lifer.observ_date}>
              {format_date(lifer.observ_date)}
            </time>
            <.link :if={@show_private_details} navigate={~p"/my/cards/#{lifer.card_id}"}>
              <.icon name="hero-clipboard-document-list" class="w-[18px] text-gray-400" />
            </.link>
          </div>
          <div class="col-start-2 col-end-5 md:col-span-1 justify-self-end text-right text-sm text-stone-500">
            <%= with location <- get_in(lifer, [Access.key!(@location_field)]) do %>
              <%!-- Do not break the line below --%>
              <span class="after:content-['_·']">{Geo.Location.name_local_part(location)}</span><span class="sr-only">, </span>
              <%= if location.cached_country do %>
                <span class="text-stone-600 font-medium whitespace-nowrap">
                  {Geo.Location.name_administrative_part(location)}
                </span>
              <% end %>
            <% end %>
          </div>
        </li>
      <% end %>
    </ol>
    """
  end

  attr :enabled, :boolean, required: true
  attr :href, :string, required: true
  attr :off_label, :string, required: true, doc: "Shown when off (describes the action to enable)"
  attr :on_label, :string, required: true, doc: "Shown when on (describes current state)"
  attr :on_action, :string, required: true, doc: "SR-only action hint when on (e.g. 'Include')"

  def toggle_switch(assigns) do
    # Fixed min-width in ch units to prevent layout jumps between on/off labels.
    # Add 1ch buffer to account for semibold being wider than the ch unit reference.
    longer_length =
      max(String.length(assigns.on_label), String.length(assigns.off_label))

    visual_label = if assigns.enabled, do: assigns.on_label, else: assigns.off_label

    assigns =
      assigns
      |> assign(:min_width_ch, longer_length + 1)
      |> assign(:visual_label, visual_label)

    ~H"""
    <.link
      patch={@href}
      class="inline-flex items-center gap-2 group no-underline"
      role="switch"
      aria-checked={to_string(@enabled)}
      aria-label={if @enabled, do: "#{@on_label}. #{@on_action}", else: @off_label}
    >
      <span
        class={[
          "relative inline-block w-9 h-5 rounded-full transition-colors",
          if(@enabled, do: "bg-forest-500", else: "bg-slate-300 group-hover:bg-slate-400")
        ]}
        aria-hidden="true"
      >
        <span class={[
          "absolute top-0.5 left-0.5 size-4 bg-white rounded-full shadow-sm transition-transform",
          if(@enabled, do: "translate-x-4")
        ]}>
        </span>
      </span>
      <span
        class={[
          "text-base font-semibold whitespace-nowrap",
          if(@enabled,
            do: "text-zinc-700",
            else: "text-zinc-400 group-hover:text-zinc-500"
          )
        ]}
        style={"min-width: #{@min_width_ch}ch"}
      >
        {@visual_label}<span :if={@enabled} class="sr-only">. {@on_action}</span>
      </span>
    </.link>
    """
  end

  @doc """
  Compact grid pill for sidebar year/month selectors.
  """
  attr :selected, :boolean, default: false
  attr :active, :boolean, default: true
  attr :href, :string, required: true
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def sidebar_filter_pill(%{selected: true} = assigns) do
    ~H"""
    <li class={@class}>
      <span class="block text-center py-1 text-[0.8125rem] leading-snug font-bold text-forest-800 bg-forest-100 border border-forest-300 rounded">
        {render_slot(@inner_block)}
      </span>
    </li>
    """
  end

  def sidebar_filter_pill(%{active: false} = assigns) do
    ~H"""
    <li class={@class}>
      <span class="block text-center py-1 text-[0.8125rem] leading-snug text-stone-400 border border-stone-200 rounded bg-transparent">
        {render_slot(@inner_block)}
      </span>
    </li>
    """
  end

  def sidebar_filter_pill(assigns) do
    ~H"""
    <li class={@class}>
      <.link
        patch={@href}
        class="block text-center py-1 text-[0.8125rem] leading-snug text-forest-600 bg-white border border-stone-200 rounded hover:bg-forest-50 no-underline"
      >
        {render_slot(@inner_block)}
      </.link>
    </li>
    """
  end

  @doc """
  Inline pill for sidebar location selector.
  """
  attr :selected, :boolean, default: false
  attr :active, :boolean, default: true
  attr :href, :string, required: true
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def sidebar_location_pill(%{selected: true} = assigns) do
    ~H"""
    <li class={["inline", @class]}>
      <span class="inline-block px-2 py-0.5 text-[0.8125rem] leading-snug font-bold text-forest-800 bg-forest-100 border border-forest-300 rounded">
        {render_slot(@inner_block)}
      </span>
    </li>
    """
  end

  def sidebar_location_pill(%{active: false} = assigns) do
    ~H"""
    <li class={["inline", @class]}>
      <span class="inline-block px-2 py-0.5 text-[0.8125rem] leading-snug text-stone-400 border border-stone-200 rounded">
        {render_slot(@inner_block)}
      </span>
    </li>
    """
  end

  def sidebar_location_pill(assigns) do
    ~H"""
    <li class={["inline", @class]}>
      <.link
        patch={@href}
        class="inline-block px-2 py-0.5 text-[0.8125rem] leading-snug text-forest-600 bg-white border border-stone-200 rounded hover:bg-forest-50 no-underline"
      >
        {render_slot(@inner_block)}
      </.link>
    </li>
    """
  end
end
