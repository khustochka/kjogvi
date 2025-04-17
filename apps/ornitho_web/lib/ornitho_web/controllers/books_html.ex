defmodule OrnithoWeb.BooksHTML do
  @moduledoc false

  use OrnithoWeb, :html

  import OrnithoWeb.TimeComponents
  import OrnithoWeb.TaxaComponents

  embed_templates "books_html/*"

  def index(assigns) do
    ~H"""
    <.header>
      {assigns[:page_title]}
    </.header>
    <.simpler_table id="books" rows={@books}>
      <:col :let={book} label="slug">
        <a href={OrnithoWeb.LinkHelper.book_path(@conn, book)} class="font-semibold text-zinc-900">
          {book.slug}
        </a>
      </:col>
      <:col :let={book} label="version">{book.version}</:col>
      <:col :let={book} label="name">{book.name}</:col>
      <:col :let={book} label="description">
        <p class="mb-3">
          {book.description}
        </p>
        <p>
          <span class="font-bold">Published:</span>
          {Calendar.strftime(book.publication_date, "%-d %b %Y")}
        </p>
      </:col>
      <:col :let={book} label="taxa">{book.taxa_count}</:col>
      <:col :let={book} label="imported">
        <.datetime time={book.imported_at} />
      </:col>
    </.simpler_table>

    <%= if @importers != [] do %>
      <h2 class="font-semibold">Import</h2>

      <.simpler_table id="importers" rows={@importers}>
        <:col :let={importer} label="slug">
          {importer.slug()}
        </:col>
        <:col :let={importer} label="version">
          {importer.version()}
        </:col>
        <:col :let={importer} label="name">
          {importer.name()}
        </:col>
        <:col :let={importer} label="description">
          <p class="mb-3">
            {importer.description()}
          </p>
          <p>
            <span class="font-bold">Published:</span>
            {Calendar.strftime(importer.publication_date(), "%-d %b %Y")}
          </p>
        </:col>
        <:col :let={importer} label="import">
          <.simple_form
            for={nil}
            phx-submit="import"
            action={OrnithoWeb.LinkHelper.import_path(@conn)}
          >
            <input type="hidden" name="importer" value={importer} />
            <:actions>
              <.button phx-disable-with="processing...">Import</.button>
            </:actions>
          </.simple_form>
        </:col>
      </.simpler_table>
    <% end %>
    """
  end
end
