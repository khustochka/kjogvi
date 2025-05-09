defmodule OrnithoWeb.TaxaComponents do
  @moduledoc """
  UI Components for rendering taxa
  """
  alias OrnithoWeb.Live.Taxa.SearchState
  use OrnithoWeb, :html

  use Gettext, backend: OrnithoWeb.Gettext

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
  attr :class, :string, default: nil

  slot :col, required: true do
    attr :label, :string
    attr :class, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def simpler_table(assigns) do
    ~H"""
    <div id={@id} class={["overflow-y-auto px-4 sm:overflow-visible sm:px-0", @class]}>
      <table class="mt-6 w-[40rem] sm:w-full">
        <thead class="text-left text-[0.8125rem] leading-6 text-zinc-500">
          <tr>
            <th :for={col <- @col} class="p-0 pb-4 pr-6 font-normal">{col[:label]}</th>
            <th class="relative p-0 pb-4"><span class="sr-only">{gettext("Actions")}</span></th>
          </tr>
        </thead>
        <tbody class="relative divide-y divide-zinc-100 border-t border-zinc-200 text-sm leading-6 text-zinc-700">
          <tr :for={row <- @rows} class="relative group hover:bg-zinc-50">
            <td
              :for={{col, i} <- Enum.with_index(@col)}
              phx-click={@row_click && @row_click.(row)}
              class={["p-0", @row_click && "hover:cursor-pointer", col[:class]]}
            >
              <div :if={i == 0}>
                <span class="absolute h-full w-4 top-0 -left-4 group-hover:bg-zinc-50 sm:rounded-l-xl" />
                <span class="absolute h-full w-4 top-0 -right-4 group-hover:bg-zinc-50 sm:rounded-r-xl" />
              </div>
              <div class="block py-4 pr-6">
                <span class="relative">
                  {render_slot(col, row)}
                </span>
              </div>
            </td>
            <td :if={@action != []} class="p-0 w-14">
              <div class="relative whitespace-nowrap py-4 text-right text-sm font-medium">
                <span
                  :for={action <- @action}
                  class="relative ml-4 font-semibold leading-6 text-zinc-900 hover:text-zinc-700"
                >
                  {render_slot(action, row)}
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
    <span
      :if={@category}
      class={[
        category_to_color(@category),
        "text-white px-1 pt-0 pb-0.5 font-semibold text-sm rounded-lg whitespace-nowrap"
      ]}
    >
      <span class="sr-only">[</span>{@category}<span class="sr-only">]</span>
    </span>
    """
  end

  @doc """
  Renders a tag if the taxon is extinct.
  """
  attr :taxon, Ornitho.Schema.Taxon, required: true

  def extinct_tag(assigns) do
    ~H"""
    <span
      :if={Ornitho.Schema.Taxon.extinct?(@taxon)}
      class="text-white bg-black px-1.5 pt-0.5 pb-1 mx-1 font-semibold text-xs rounded-lg"
      title="Extinct"
    >
      <span aria-hidden="true">EX</span>
      <span class="sr-only">Extinct</span>
    </span>
    """
  end

  @doc """
  Renders a taxon scientific name, which should be always italisized.
  """
  attr :taxon, Ornitho.Schema.Taxon, required: true
  attr :search_state, :any, default: struct(SearchState)
  attr :class, :any, default: nil

  def sci_name(assigns) do
    ~H"""
    <em class={[~w[italic sci_name], @class]} phx-no-format><.highlighted
        content={@taxon.name_sci}
        search_state={@search_state} /></em>
    """
  end

  attr :content, :string, required: true
  attr :search_state, :any, default: struct(SearchState)

  def highlighted(assigns) do
    ~H"""
    {if @search_state.enabled, do: highlighted_content(assigns), else: @content}
    """
  end

  defp highlighted_content(assigns) do
    ~H"""
    <.unchanged phx-no-format><%= for vals <- split_for_highlight(@content, @search_state.term) do %><%= maybe_highlighted(vals) %><% end %></.unchanged>
    """
  end

  defp maybe_highlighted(%{type: :highlight, text: _text} = assigns) do
    ~H(<span class="bg-yellow-200">{@text}</span>)
  end

  defp maybe_highlighted(%{type: _, text: _text} = assigns) do
    ~H"{@text}"
  end

  defp split_for_highlight(content, term) do
    content
    |> String.split(~r{#{term}}i, include_captures: true)
    |> Enum.map(fn str ->
      if str =~ ~r{\A#{term}\Z}i do
        :highlight
      else
        :plain
      end
      |> then(fn type ->
        %{type: type, text: str}
      end)
    end)
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
