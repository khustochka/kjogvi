defmodule KjogviWeb.Live.Lifelist.Components do
  @moduledoc false

  use KjogviWeb, :html

  alias Kjogvi.Geo

  attr :id, :string, required: true
  attr :show_private_details, :boolean, default: false
  attr :groups, :list, required: true
  attr :location_field, :atom, required: true
  attr :sort, :atom, default: :date
  attr :anchor_prefix, :string, default: ""

  def lifers_list(assigns) do
    ~H"""
    <div id={@id}>
      <div id={"#{@id}-by-#{@sort}"}>
        <%= for {{header, lifers_with_rank}, group_index} <- Enum.with_index(@groups) do %>
          <.group_header
            :if={header != :none}
            header={header}
            anchor_prefix={@anchor_prefix}
            class={if group_index == 0, do: "mt-0"}
          />
          <ol class="border-t border-stone-200">
            <%= for {lifer, rank} <- lifers_with_rank do %>
              <.lifer_row
                id={lifer_id(@anchor_prefix, @sort, rank)}
                value={rank}
                lifer={lifer}
                location_field={@location_field}
                show_private_details={@show_private_details}
              />
            <% end %>
          </ol>
        <% end %>
      </div>
    </div>
    """
  end

  defp lifer_id(_prefix, :taxonomy, _rank), do: nil
  defp lifer_id(prefix, :date, rank), do: "#{prefix}lifer-#{rank}"

  attr :header, :any, required: true
  attr :anchor_prefix, :string, default: ""
  attr :class, :any, default: nil

  defp group_header(%{header: {:taxonomy, order, family}} = assigns) do
    assigns = assign(assigns, order: order, family: family)

    ~H"""
    <.group_header_box
      anchor_id={@family && "#{@anchor_prefix}#{@family}"}
      class={@class}
    >
      <span :if={@order}>{@order}</span>
      <span :if={@order && @family} class="text-stone-300 mx-1">&middot;</span>
      <span :if={@family} class="text-stone-700">{@family}</span>
    </.group_header_box>
    """
  end

  defp group_header(%{header: {:year, year}} = assigns) do
    assigns = assign(assigns, :year, year)

    ~H"""
    <.group_header_box
      anchor_id={"#{@anchor_prefix}first-record-#{@year}"}
      class={@class}
    >
      First recorded in <span class="text-stone-700">{@year}</span>
    </.group_header_box>
    """
  end

  attr :anchor_id, :string, default: nil
  attr :class, :any, default: nil
  slot :inner_block, required: true

  defp group_header_box(assigns) do
    ~H"""
    <h3
      id={@anchor_id}
      class={[
        "scroll-mt-4 mt-8 mb-0! py-3 bg-stone-50/50",
        "px-2 text-sm font-header font-semibold tracking-wide uppercase text-stone-500",
        @class
      ]}
    >
      {render_slot(@inner_block)}
    </h3>
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
      <span
        class="lifer-counter text-stone-400 text-sm col-span-1 justify-self-end tabular-nums"
        aria-hidden="true"
        data-value={@value}
      ></span>
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
        <%= with location when not is_nil(location) <-
                 get_in(@lifer, [Access.key!(@location_field)]) do %>
          {Geo.Location.long_name_from_levels(location)}
        <% end %>
      </div>
    </li>
    """
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
      <.inline_filter_pill href={@date_href} selected={@current_sort == :date}>
        By date
      </.inline_filter_pill>
      <.inline_filter_pill href={@taxonomy_href} selected={@current_sort == :taxonomy}>
        Taxonomic
      </.inline_filter_pill>
    </ul>
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
          "relative inline-block w-9 h-5 lg:w-8 lg:h-4.5 rounded-full transition-colors",
          if(@enabled, do: "bg-forest-500", else: "bg-slate-300 group-hover:bg-slate-400")
        ]}
        aria-hidden="true"
      >
        <span class={[
          "absolute top-0.5 left-0.5 size-4 lg:size-3.5 bg-white rounded-full shadow-sm transition-transform",
          if(@enabled, do: "translate-x-4 lg:translate-x-3.5")
        ]}></span>
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
          <span class="sr-only">(remove)</span>
        </span>
      </.link>
    </li>
    """
  end
end
