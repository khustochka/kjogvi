defmodule KjogviWeb.PaginationComponents do
  @moduledoc """
  Page-number navigation for `Flop.Meta` paginated results.
  """
  use Phoenix.Component

  @window 2

  @doc ~S"""
  Renders numbered page navigation for a `Flop.Meta`.

  `path` builds the URL for a page number; each index has its own builder so
  page links keep the area's base path and any active filter/search params.
  Links patch, so the index's `handle_params` loads the new page.

      defp images_path(1), do: ~p"/my/images"
      defp images_path(page), do: ~p"/my/images/page/#{page}"

      <.pagination meta={@meta} path={&images_path/1} />

  Renders nothing when everything fits on one page.
  """
  attr :meta, Flop.Meta, required: true
  attr :path, :any, required: true
  attr :id, :string, default: "pagination"

  def pagination(assigns) do
    ~H"""
    <nav :if={@meta.total_pages > 1} id={@id} aria-label="Pagination">
      <ul class="pagination sm:flex gap-2 mt-4">
        <.page_link
          :if={@meta.current_page > 2}
          page={1}
          path={@path}
          title="First page"
          label="«"
        />
        <.page_link
          :if={@meta.has_previous_page?}
          page={@meta.current_page - 1}
          path={@path}
          title="Previous page"
          label="‹"
          rel="prev"
        />
        <li :for={item <- page_items(@meta)} class={item_class(item)}>
          <span :if={item == :gap} class="inline-block py-2 px-2">…</span>
          <span
            :if={item == @meta.current_page}
            class={"#{page_num_class()} active font-bold"}
            aria-current="page"
          >{item}</span>
          <.link
            :if={is_integer(item) and item != @meta.current_page}
            patch={@path.(item)}
            class={link_class()}
          >{item}</.link>
        </li>
        <.page_link
          :if={@meta.has_next_page?}
          page={@meta.current_page + 1}
          path={@path}
          title="Next page"
          label="›"
          rel="next"
        />
        <.page_link
          :if={@meta.current_page < @meta.total_pages - 1}
          page={@meta.total_pages}
          path={@path}
          title="Last page"
          label="»"
        />
      </ul>
    </nav>
    """
  end

  attr :page, :integer, required: true
  attr :path, :any, required: true
  attr :title, :string, required: true
  attr :label, :string, required: true
  attr :rest, :global, include: ~w(rel)

  defp page_link(assigns) do
    ~H"""
    <li class="page-item text-center my-2 border">
      <.link patch={@path.(@page)} title={@title} class={link_class()} {@rest}>{@label}</.link>
    </li>
    """
  end

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

  defp item_class(:gap), do: "page-item text-center my-2 disabled border-0"
  defp item_class(_page), do: "page-item text-center my-2 border"

  defp page_num_class, do: "page-link inline-block whitespace-nowrap py-2 px-4 w-full h-full"
  defp link_class, do: "#{page_num_class()} hover:bg-zinc-200 no-underline"
end
