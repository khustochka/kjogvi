defmodule KjogviWeb.PaginationComponents do
  @moduledoc """
  Components for pagination.
  """

  use Phoenix.Component

  # alias Phoenix.LiveView.JS
  # import KjogviWeb.Gettext

  @doc """
  Simple pagination UI.
  """
  attr :page_num, :integer, required: true
  attr :url_generator, :any, required: true

  def simple_pagination(%{page_num: _} = assigns) do
    ~H"""
    <div class="simple-pagination flex flex-row gap-4">
      <div class="simple-pagination-first" :if={@page_num > 2}>
        <a href={@url_generator.(1)}>Page 1</a>
        &nbsp;|
      </div>
      <div class="simple-pagination-prev" :if={@page_num > 1}>
        <a href={@url_generator.(@page_num - 1)}>
        Page <%= assigns.page_num - 1 %>
        </a>
      </div>
      <div class="simple-pagination-current">
        <b>Page <%= assigns.page_num %></b>
      </div>
      <div class="simple-pagination-next">
        <a href={@url_generator.(@page_num + 1)}>
        Page <%= assigns.page_num + 1 %>
        </a>
      </div>
    </div>
    """
  end
end
