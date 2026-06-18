defmodule OrnithoWeb.Live.Book.Index do
  @moduledoc false

  use OrnithoWeb, :live_view

  import OrnithoWeb.TimeComponents
  import OrnithoWeb.TaxaComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Books")
     |> assign(:importing, MapSet.new())
     |> load_books()}
  end

  @impl true
  def handle_event("import", %{"importer" => importer_string} = params, socket) do
    force = params["force"] == "true"

    if importer_string in Ornitho.Importer.legit_importers_string() do
      importer = String.to_existing_atom(importer_string)

      {:noreply,
       socket
       |> assign(:importing, MapSet.put(socket.assigns.importing, importer_string))
       |> start_async({:import, importer_string}, fn ->
         importer.process_import(force: force)
       end)}
    else
      {:noreply, put_flash(socket, :error, "Not an allowed importer.")}
    end
  end

  @impl true
  def handle_async({:import, importer_string}, {:ok, result}, socket) do
    socket =
      case result do
        {:ok, _} -> socket
        {:error, err} -> put_flash(socket, :error, err)
      end

    {:noreply,
     socket
     |> assign(:importing, MapSet.delete(socket.assigns.importing, importer_string))
     |> load_books()}
  end

  def handle_async({:import, importer_string}, {:exit, reason}, socket) do
    {:noreply,
     socket
     |> put_flash(:error, "Import failed: #{inspect(reason)}")
     |> assign(:importing, MapSet.delete(socket.assigns.importing, importer_string))
     |> load_books()}
  end

  defp load_books(socket) do
    socket
    |> assign(:books, Ornitho.Finder.Book.all())
    |> assign(:importers, Ornitho.Importer.unimported())
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header class="text-xl">
      {@page_title}
    </.header>
    <.simpler_table id="taxonomy-index-books" rows={@books} class="mb-10">
      <:col :let={book} label="slug and version" class="w-48">
        <span class="font-mono text-xl font-semibold text-zinc-600">{book.slug}</span>
        <span class="font-mono text-lg text-zinc-500">{book.version}</span>
      </:col>
      <:col :let={book} label="name">
        <h3 class="text-2xl font-bold text-brand mb-4 opacity-75 hover:opacity-90">
          <.link navigate={OrnithoWeb.LinkHelper.book_path(@socket, book)}>
            {book.name}
          </.link>
        </h3>
        <p>
          <span class="font-bold">Published:</span>
          {Calendar.strftime(book.publication_date, "%-d %b %Y")}
        </p>
      </:col>
      <:col :let={book} label="taxa" class="w-20">{book.taxa_count}</:col>
      <:col :let={book} label="imported" class="w-36">
        <.datetime time={book.imported_at} />
        <%= if MapSet.member?(@importing, book.importer) do %>
          <span class="text-xs font-semibold leading-6 text-red-600">importing...</span>
        <% else %>
          <form id={"reimport-#{book.importer}"} phx-submit="import">
            <input type="hidden" name="importer" value={book.importer} />
            <input type="hidden" name="force" value="true" />
            <button
              class={[
                "py-0.5 px-3 bg-red-600 disabled:bg-red-300",
                "phx-submit-loading:opacity-75 rounded-lg",
                "text-xs font-semibold leading-6 text-white active:text-white/80"
              ]}
              phx-disable-with="importing..."
            >
              Reimport
            </button>
          </form>
        <% end %>
      </:col>
    </.simpler_table>

    <%= if @importers != [] do %>
      <h2 class="text-xl font-semibold ">Available for import</h2>

      <.simpler_table id="taxonomy-index-importers" rows={@importers}>
        <:col :let={importer} label="slug" class="w-48">
          <span class="font-mono text-xl font-semibold text-zinc-600">{importer.slug()}</span>
          <span class="font-mono text-lg text-zinc-500">{importer.version()}</span>
        </:col>
        <:col :let={importer} label="name">
          <h3 class="text-2xl font-bold text-zinc-600 opacity-90 mb-4">
            {importer.name()}
          </h3>
          <p>
            <span class="font-bold">Published:</span>
            {Calendar.strftime(importer.publication_date(), "%-d %b %Y")}
          </p>
        </:col>
        <:col :let={importer} label="import" class="w-36">
          <%= if MapSet.member?(@importing, Atom.to_string(importer)) do %>
            <span class="text-sm font-semibold leading-6 text-zinc-700">importing...</span>
          <% else %>
            <form id={"import-#{importer}"} phx-submit="import">
              <input type="hidden" name="importer" value={importer} />
              <.button class="disabled:bg-zinc-500" phx-disable-with="importing...">
                Import
              </.button>
            </form>
          <% end %>
        </:col>
      </.simpler_table>
    <% end %>
    """
  end
end
