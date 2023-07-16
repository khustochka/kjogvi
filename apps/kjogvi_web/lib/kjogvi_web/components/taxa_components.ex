defmodule KjogviWeb.TaxaComponents do
  @moduledoc """
  UI Components for rendering taxa
  """
  use KjogviWeb, :html

  import KjogviWeb.Gettext

  @doc """
  Renders a table with generic styling. Simplified compared to the table from CoreComponents.

  ## Examples

      <.simpler_table id="users" rows={@users}>
        <:col :let={user} label="id"><%= user.id %></:col>
        <:col :let={user} label="username"><%= user.username %></:col>
      </.simpler_table>
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

  @doc """
  Renders a tag with taxon category.
  """
  attr :category, :string

  def category_tag(assigns) do
    ~H"""
    <span :if={@category} class={[category_to_color(@category), "text-white px-1 pt-0 pb-0.5 font-semibold text-sm rounded-lg"]}>
    <%= @category %>
    </span>
    """
  end

  @doc """
  Renders a tag if the taxon is extinct.
  """
  attr :taxon, Ornitho.Schema.Taxon, required: true

  def extinct_tag(assigns) do
    ~H"""
    <span :if={Ornitho.Schema.Taxon.is_extinct?(@taxon)} class="text-white bg-black px-1.5 pt-0.5 pb-1 mx-1 font-semibold text-xs rounded-lg" title="Extinct">
    EX
    <span class="sr-only">Extinct</span>
    </span>
    """
  end

  @doc """
  Renders a taxon scientific name, which should be always italisized.
  """
  attr :taxon, Ornitho.Schema.Taxon, required: true

  def sci_name(assigns) do
    ~H"""
    <em class="italic"><%= @taxon.name_sci %></em>
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
