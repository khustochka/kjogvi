defmodule KjogviWeb.Live.Lifelist.Components do
  @moduledoc false

  use KjogviWeb, :html

  alias Kjogvi.Geo

  attr :id, :string, required: true
  attr :show_private_details, :boolean, default: false
  attr :lifelist, :list, required: true
  attr :location_field, :atom, required: true
  attr :sort, :atom, default: :date

  def lifers_list(%{sort: :taxonomy} = assigns) do
    groups = group_by_taxonomy(assigns.lifelist.list)
    assigns = assign(assigns, :groups, groups)

    ~H"""
    <ol id={@id} class="lifers-list lifers-list-asc border-t border-stone-200">
      <%= for {{order, family}, lifers} <- @groups do %>
        <li class="py-3 border-b border-stone-100 bg-stone-50/50 scroll-mt-4">
          <a :if={family} id={family}></a>
          <div class="px-2 text-sm uppercase tracking-wide text-stone-500 font-header font-semibold">
            <span :if={order}>{order}</span>
            <span :if={order && family} class="text-stone-300 mx-1">&middot;</span>
            <span :if={family} class="text-stone-700">{family}</span>
          </div>
        </li>
        <%= for lifer <- lifers do %>
          <.lifer_row
            lifer={lifer}
            location_field={@location_field}
            show_private_details={@show_private_details}
          />
        <% end %>
      <% end %>
    </ol>
    """
  end

  def lifers_list(assigns) do
    ~H"""
    <ol
      id={@id}
      class="lifers-list border-t border-stone-200"
      style={"--lifersTotal:#{@lifelist.total + 1};"}
    >
      <%= for {lifer, i} <- Enum.with_index(@lifelist.list) do %>
        <.lifer_row
          id={"lifer-#{@lifelist.total - i}"}
          value={@lifelist.total - i}
          lifer={lifer}
          location_field={@location_field}
          show_private_details={@show_private_details}
        />
      <% end %>
    </ol>
    """
  end

  attr :id, :string, default: nil
  attr :value, :integer, default: nil
  attr :lifer, :any, required: true
  attr :location_field, :atom, required: true
  attr :show_private_details, :boolean, default: false

  defp lifer_row(assigns) do
    ~H"""
    <li
      id={@id}
      value={@value}
      class="py-4 border-b border-stone-100 grid grid-cols-[3.5ch_2fr_auto_3fr] gap-x-2 md:gap-x-6 gap-y-1 items-top md:items-center"
    >
      <span class="counter text-stone-400 text-sm col-span-1 justify-self-end tabular-nums"></span>
      <div class="mb-1 col-span-3 md:col-span-1">
        <.species_link species={@lifer.species_page} />
      </div>
      <div class="col-start-2 col-end-5 md:col-span-1 justify-self-end text-right text-sm text-stone-500">
        <time time={@lifer.observ_date}>
          {format_date(@lifer.observ_date)}
        </time>
        <.icon_link
          :if={@show_private_details}
          navigate={~p"/my/cards/#{@lifer.card_id}"}
          icon="hero-clipboard-document-list"
          label="View card"
          class="text-gray-400"
        />
      </div>
      <div class="col-start-2 col-end-5 md:col-span-1 justify-self-end text-right text-sm text-stone-500">
        <%= with location <- get_in(@lifer, [Access.key!(@location_field)]) do %>
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
    """
  end

  defp group_by_taxonomy(lifers) do
    lifers
    |> Enum.chunk_by(fn lifer ->
      {lifer.species_page.order, lifer.species_page.family}
    end)
    |> Enum.map(fn [first | _] = chunk ->
      {{first.species_page.order, first.species_page.family}, chunk}
    end)
  end

  attr :current_sort, :atom, required: true
  attr :date_href, :string, required: true
  attr :taxonomy_href, :string, required: true

  def sort_selector(assigns) do
    ~H"""
    <ul class="inline-flex items-center gap-1 list-none" aria-label="Sort">
      <li class="text-xs uppercase tracking-wide text-stone-500 font-semibold mr-1">
        Sort:
      </li>
      <.sort_pill href={@date_href} selected={@current_sort == :date}>By date</.sort_pill>
      <.sort_pill href={@taxonomy_href} selected={@current_sort == :taxonomy}>
        Taxonomic
      </.sort_pill>
    </ul>
    """
  end

  attr :href, :string, required: true
  attr :selected, :boolean, default: false
  slot :inner_block, required: true

  defp sort_pill(%{selected: true} = assigns) do
    ~H"""
    <li>
      <span class="inline-block px-3 py-1.5 text-sm leading-snug font-bold text-forest-800 bg-forest-100 border border-forest-300 rounded">
        {render_slot(@inner_block)}
      </span>
    </li>
    """
  end

  defp sort_pill(assigns) do
    ~H"""
    <li>
      <.link
        patch={@href}
        class="inline-block px-3 py-1.5 text-sm leading-snug text-forest-600 bg-white border border-stone-300 rounded hover:bg-forest-50 active:bg-forest-100 active:border-forest-300 phx-click-loading:bg-forest-50 phx-click-loading:border-forest-200 transition-colors no-underline"
      >
        {render_slot(@inner_block)}
      </.link>
    </li>
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
          "relative inline-block w-9 h-5 lg:w-8 lg:h-[1.125rem] rounded-full transition-colors",
          if(@enabled, do: "bg-forest-500", else: "bg-slate-300 group-hover:bg-slate-400")
        ]}
        aria-hidden="true"
      >
        <span class={[
          "absolute top-0.5 left-0.5 size-4 lg:size-3.5 bg-white rounded-full shadow-sm transition-transform",
          if(@enabled, do: "translate-x-4 lg:translate-x-3.5")
        ]}>
        </span>
      </span>
      <span
        class={[
          "text-base lg:text-sm font-semibold whitespace-nowrap",
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

  attr :label, :string, required: true
  attr :href, :string, required: true

  def filter_badge(assigns) do
    ~H"""
    <li>
      <.link
        patch={@href}
        class="group inline-flex items-stretch rounded-sm bg-stone-200/70 hover:bg-stone-300/70 text-sm text-stone-700 no-underline whitespace-nowrap"
        aria-label={"Remove filter: #{@label}"}
      >
        <span class="px-2.5 py-1">{@label}</span>
        <span class="flex items-center px-1.5 border-l border-stone-400/20">
          <.icon
            name="hero-x-mark"
            class="w-4 h-4 text-stone-500 group-hover:text-stone-700"
          />
        </span>
      </.link>
    </li>
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
      <span class="block text-center py-2 lg:py-1.5 text-base lg:text-sm leading-snug font-bold text-forest-800 bg-forest-100 border border-forest-300 rounded">
        {render_slot(@inner_block)}
      </span>
    </li>
    """
  end

  def sidebar_filter_pill(%{active: false} = assigns) do
    ~H"""
    <li class={@class}>
      <span class="block text-center py-2 lg:py-1.5 text-base lg:text-sm leading-snug text-stone-300 border border-stone-100 rounded bg-transparent">
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
        class="block text-center py-2 lg:py-1.5 text-base lg:text-sm leading-snug text-forest-600 bg-white border border-stone-300 rounded hover:bg-forest-50 active:bg-forest-100 active:border-forest-300 phx-click-loading:bg-forest-50 phx-click-loading:border-forest-200 transition-colors no-underline"
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
      <span class="inline-block px-3 py-1.5 text-base lg:text-sm leading-snug font-bold text-forest-800 bg-forest-100 border border-forest-300 rounded">
        {render_slot(@inner_block)}
      </span>
    </li>
    """
  end

  def sidebar_location_pill(%{active: false} = assigns) do
    ~H"""
    <li class={["inline", @class]}>
      <span class="inline-block px-3 py-1.5 text-base lg:text-sm leading-snug text-stone-300 border border-stone-100 rounded">
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
        class="inline-block px-3 py-1.5 text-base lg:text-sm leading-snug text-forest-600 bg-white border border-stone-300 rounded hover:bg-forest-50 active:bg-forest-100 active:border-forest-300 phx-click-loading:bg-forest-50 phx-click-loading:border-forest-200 transition-colors no-underline"
      >
        {render_slot(@inner_block)}
      </.link>
    </li>
    """
  end
end
