defmodule OrnithoWeb.PaginationComponents do
  @moduledoc """
  Components for pagination.
  """

  use Phoenix.Component

  # import OrnithoWeb.Gettext

  # alias Phoenix.LiveView.JS

  @doc ~S"""
  Simple pagination navigation. Renders links to the next and previous pages (except if
  the current page is 1). For pages after the 2nd, also shows link to the 1st page.

  ## Examples

      <.simple_pagination page_num={@page_num} url_generator={&OrnithoWeb.LinkHelper.path(@conn, "/page/#{&1}"} />
  """
  attr :page_num, :integer, default: 1
  attr :url_generator, :any, required: true

  def simple_pagination(assigns) do
    ~H"""
    <nav aria-label="Pagination" class="simple-pagination flex flex-row gap-4">
      <div :if={@page_num > 2} class="simple-pagination-first">
        <.link patch={@url_generator.(1)}>Page 1</.link> &nbsp;|
      </div>
      <div :if={@page_num > 1} class="simple-pagination-prev">
        <.link patch={@url_generator.(@page_num - 1)}>
          Page <%= assigns.page_num - 1 %>
        </.link>
      </div>
      <div class="simple-pagination-current">
        <b>Page <%= assigns.page_num %></b>
      </div>
      <div class="simple-pagination-next">
        <.link patch={@url_generator.(@page_num + 1)}>
          Page <%= assigns.page_num + 1 %>
        </.link>
      </div>
    </nav>
    """
  end
end
