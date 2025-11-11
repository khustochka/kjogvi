defmodule OrnithoWeb.BooksHTML do
  @moduledoc false

  use OrnithoWeb, :html

  import OrnithoWeb.TimeComponents
  import OrnithoWeb.TaxaComponents

  embed_templates "books_html/*"

  def index(assigns) do
    ~H"""
    <.header class="text-xl">
      {assigns[:page_title]}
    </.header>
    <.simpler_table id="books" rows={@books} class="mb-10">
      <:col :let={book} label="slug and version" class="w-2/10">
        <span class="font-mono text-xl font-semibold text-zinc-600">{book.slug}</span>
        <span class="font-mono text-lg text-zinc-500">{book.version}</span>
      </:col>
      <:col :let={book} label="name" class="w-6/10">
        <h3 class="text-2xl font-bold text-brand mb-4 opacity-75 hover:opacity-90">
          <a href={OrnithoWeb.LinkHelper.book_path(@conn, book)}>
            {book.name}
          </a>
        </h3>
        <p>
          <span class="font-bold">Published:</span>
          {Calendar.strftime(book.publication_date, "%-d %b %Y")}
        </p>
      </:col>
      <:col :let={book} label="taxa" class="w-1/10">{book.taxa_count}</:col>
      <:col :let={book} label="imported" class="w-1/10">
        <.datetime time={book.imported_at} />
        <.simple_form
          for={nil}
          phx-submit="import"
          action={OrnithoWeb.LinkHelper.import_path(@conn)}
        >
          <input type="hidden" name="importer" value={book.importer} />
          <input type="hidden" name="force" value="true" />
          <:actions>
            <button
              class={[
                "py-0.5 px-3 bg-red-600",
                "phx-submit-loading:opacity-75 rounded-lg",
                "text-xs font-semibold leading-6 text-white active:text-white/80"
              ]}
              phx-disable-with="processing..."
            >
              Reimport
            </button>
          </:actions>
        </.simple_form>
      </:col>
    </.simpler_table>

    <%= if @importers != [] do %>
      <h2 class="text-xl font-semibold ">Available for import</h2>

      <.simpler_table id="importers" rows={@importers}>
        <:col :let={importer} label="slug" class="w-2/10">
          <span class="font-mono text-xl font-semibold text-zinc-600">{importer.slug()}</span>
          <span class="font-mono text-lg text-zinc-500">{importer.version()}</span>
        </:col>
        <:col :let={importer} label="name" class="w-7/10">
          <h3 class="text-2xl font-bold text-zinc-600 opacity-90 mb-4">
            {importer.name()}
          </h3>
          <p>
            <span class="font-bold">Published:</span>
            {Calendar.strftime(importer.publication_date(), "%-d %b %Y")}
          </p>
        </:col>
        <:col :let={importer} label="import" class="w-1/10">
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
