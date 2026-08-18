defmodule KjogviWeb.PaginationComponents do
  @moduledoc """
  Page-number navigation for `Flop.Meta` paginated results.
  """
  use Phoenix.Component

  @window 2

  @item_class "inline-block min-w-9 px-3 py-1.5 text-center text-base lg:text-sm leading-snug border rounded"
  @link_class "text-forest-600 bg-white border-stone-400 hover:bg-forest-50 no-underline"

  @doc ~S"""
  Renders numbered page navigation for a `Flop.Meta`.

  `path` builds the URL for a page number; each index has its own builder so
  page links keep the area's base path and any active filter/search params.
  Links patch, so the index's `handle_params` loads the new page.

      defp images_path(1), do: ~p"/my/images"
      defp images_path(page), do: ~p"/my/images/page/#{page}"

      <.pagination meta={@meta} path={&images_path/1} />

  The prev/next controls keep their slot when they are unavailable, so the
  arrows stay put under the pointer while paging through. The first and last
  pages are reached by their numbers, which are always shown.

  Pass `anchor` with the id of an element above the list so a page change lands
  there rather than leaving the reader where they clicked:

      <.pagination meta={@meta} path={&images_path/1} anchor="images-grid" />

  Renders nothing when everything fits on one page.
  """
  attr :meta, Flop.Meta, required: true
  attr :path, :any, required: true
  attr :id, :string, default: "pagination"
  attr :label, :string, default: "Pagination"
  attr :class, :any, default: "mt-4"
  attr :anchor, :string, default: nil

  def pagination(assigns) do
    assigns =
      assign(assigns,
        item_class: @item_class,
        link_class: @link_class,
        path: anchored(assigns.path, assigns[:anchor])
      )

    ~H"""
    <nav :if={@meta.total_pages > 1} id={@id} aria-label={@label} class={@class}>
      <ul class="flex flex-wrap items-baseline justify-center gap-2">
        <.step
          page={@meta.current_page - 1}
          path={@path}
          enabled={@meta.has_previous_page?}
          title="Previous page"
          label="‹"
          rel="prev"
        />
        <li :for={item <- page_items(@meta)}>
          <span :if={item == :gap} class="inline-block px-1 py-1.5 text-stone-500">…</span>
          <span
            :if={item == @meta.current_page}
            aria-current="page"
            class={[@item_class, "font-bold text-forest-800 bg-forest-100 border-forest-300"]}
          >{item}</span>
          <.link
            :if={is_integer(item) and item != @meta.current_page}
            patch={@path.(item)}
            class={[@item_class, @link_class]}
            phx-no-format
          >{item}</.link>
        </li>
        <.step
          page={@meta.current_page + 1}
          path={@path}
          enabled={@meta.has_next_page?}
          title="Next page"
          label="›"
          rel="next"
        />
      </ul>
    </nav>
    """
  end

  # Prev/next. Rendered as an inert span when out of range so the control keeps
  # its place in the row rather than shifting the others.
  attr :page, :integer, required: true
  attr :path, :any, required: true
  attr :enabled, :boolean, required: true
  attr :title, :string, required: true
  attr :label, :string, required: true
  attr :rest, :global, include: ~w(rel)

  defp step(assigns) do
    assigns = assign(assigns, item_class: @item_class, link_class: @link_class)

    ~H"""
    <li>
      <.link
        :if={@enabled}
        patch={@path.(@page)}
        title={@title}
        class={[@item_class, @link_class]}
        {@rest}
      >{@label}</.link>
      <span
        :if={!@enabled}
        title={@title}
        aria-disabled="true"
        class={[@item_class, "text-stone-300 border-stone-200"]}
      >{@label}</span>
    </li>
    """
  end

  # Appends the anchor to every page URL, so following a link scrolls to the top
  # of the list instead of leaving the reader wherever the control was.
  defp anchored(path, nil), do: path
  defp anchored(path, anchor), do: fn page -> "#{path.(page)}##{anchor}" end

  # A window of pages around the current one, with the first and last page always
  # present and `:gap` marking the elided stretches.
  defp page_items(%Flop.Meta{current_page: current, total_pages: total}) do
    around = max(current - @window, 1)..min(current + @window, total)//1

    [1, around, total]
    |> Enum.flat_map(fn
      page when is_integer(page) -> [page]
      range -> Enum.to_list(range)
    end)
    |> Enum.uniq()
    |> Enum.sort()
    |> insert_gaps()
  end

  defp insert_gaps([page | rest]) do
    Enum.reduce(rest, [page], fn page, [prev | _] = acc ->
      if page - prev > 1, do: [page, :gap | acc], else: [page | acc]
    end)
    |> Enum.reverse()
  end
end
