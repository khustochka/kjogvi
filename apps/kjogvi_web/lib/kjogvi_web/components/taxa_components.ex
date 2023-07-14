defmodule KjogviWeb.TaxaComponents do
  @moduledoc """
  UI Components for rendering taxa
  """
  use Phoenix.Component
  use KjogviWeb, :verified_routes

  # alias Phoenix.LiveView.JS
  import KjogviWeb.Gettext

  @doc ~S"""
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id"><%= user.id %></:col>
        <:col :let={user} label="username"><%= user.username %></:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :row_click, :any, default: nil
  attr :rows, :list, required: true

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def simpler_table(assigns) do
    ~H"""
    <div id={@id} class="overflow-y-auto px-4 sm:overflow-visible sm:px-0">
      <table class="mt-6 w-[40rem] sm:w-full">
        <thead class="text-left text-[0.8125rem] leading-6 text-zinc-500">
          <tr>
            <th :for={col <- @col} class="p-0 pb-4 pr-6 font-normal"><%= col[:label] %></th>
            <th class="relative p-0 pb-4"><span class="sr-only"><%= gettext("Actions") %></span></th>
          </tr>
        </thead>
        <tbody class="relative divide-y divide-zinc-100 border-t border-zinc-200 text-sm leading-6 text-zinc-700">
          <tr :for={row <- @rows} class="relative group hover:bg-zinc-50">
            <td
              :for={{col, i} <- Enum.with_index(@col)}
              phx-click={@row_click && @row_click.(row)}
              class={["p-0", @row_click && "hover:cursor-pointer"]}
            >
              <div :if={i == 0}>
                <span class="absolute h-full w-4 top-0 -left-4 group-hover:bg-zinc-50 sm:rounded-l-xl" />
                <span class="absolute h-full w-4 top-0 -right-4 group-hover:bg-zinc-50 sm:rounded-r-xl" />
              </div>
              <div class="block py-4 pr-6">
                <span class="relative">
                  <%= render_slot(col, row) %>
                </span>
              </div>
            </td>
            <td :if={@action != []} class="p-0 w-14">
              <div class="relative whitespace-nowrap py-4 text-right text-sm font-medium">
                <span
                  :for={action <- @action}
                  class="relative ml-4 font-semibold leading-6 text-zinc-900 hover:text-zinc-700"
                >
                  <%= render_slot(action, row) %>
                </span>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  def category_tag(assigns) do
    ~H"""
    <span class={[category_to_color(@category), "text-white px-1 pt-0 pb-0.5 font-semibold text-sm rounded-lg"]}>
    <%= @category %>
    </span>
    """
  end

  def taxa_table(assigns) do
    ~H"""
    <.simpler_table id="taxa" rows={@taxa}>
      <:col :let={taxon} label="no"><%= taxon.sort_order %></:col>
      <:col :let={taxon} label="code">
          <span class="font-mono"><%= taxon.code %></span>
      </:col>
      <:col :let={taxon} label="name">
          <div class="text-zinc-900">
          <strong>
          <.link navigate={~p"/taxonomy/#{@book.slug}/#{@book.version}/#{taxon.code}"}>
          <i><%= taxon.name_sci %></i>
          </.link>
          </strong>
          </div>
          <div><%= taxon.name_en %></div>
      </:col>
      <:col :let={taxon} label="category & parent species">
          <div class="text-center" :if={taxon.category}>
              <.category_tag category={taxon.category} />
          </div>
          <div class="text-center" :if={taxon.parent_species}>
          <.link navigate={~p"/taxonomy/#{@book.slug}/#{@book.version}/#{taxon.parent_species.code}"}>
          <i><%= taxon.parent_species.name_sci %></i>
          </.link>
          </div>
      </:col>
      <:col :let={taxon} label="taxonomy">
          <div><%= taxon.order %></div>
          <div><%= taxon.family %></div>
      </:col>
    </.simpler_table>
    """
  end

  defp category_to_color(cat) do
    case cat do
      "species" -> "bg-green-500"
      "issf" -> "bg-blue-500"
      c when c in ["slash", "spuh", "form"] -> "bg-rose-400"
      c when c in ["domestic", "intergrade", "hybrid"] -> "bg-zinc-400"
      _ -> "bg-zinc-400"
    end
  end
end
