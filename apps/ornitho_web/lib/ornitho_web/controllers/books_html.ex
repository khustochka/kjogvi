defmodule OrnithoWeb.BooksHTML do
  @moduledoc false

  use OrnithoWeb, :html

  import OrnithoWeb.TimeComponents
  import OrnithoWeb.TaxaComponents

  embed_templates "books_html/*"

  def index(assigns) do
    ~H"""
    <.header>
      <%= assigns[:page_title] %>
    </.header>
    <.simpler_table id="books" rows={@books}>
      <:col :let={book} label="slug">
        <a
          href={OrnithoWeb.LinkHelper.path(@conn, "/#{book.slug}/#{book.version}")}
          class="font-semibold text-zinc-900"
        >
          <%= book.slug %>
        </a>
      </:col>
      <:col :let={book} label="version"><%= book.version %></:col>
      <:col :let={book} label="name"><%= book.name %></:col>
      <:col :let={book} label="description"><%= book.description %></:col>
      <:col :let={book} label="taxa"><%= book.taxa_count %></:col>
      <:col :let={book} label="imported">
        <.datetime time={book.imported_at} />
      </:col>
    </.simpler_table>
    """
  end
end
