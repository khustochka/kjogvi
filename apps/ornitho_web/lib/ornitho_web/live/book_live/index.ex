defmodule OrnithoWeb.Live.Book.Index do
  @moduledoc false

  use OrnithoWeb, :live_view

  import OrnithoWeb.TimeComponents
  import OrnithoWeb.TaxaComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     # Maps each running import task's monitor ref to its importer string, so the
     # right table row shows "importing..." and is cleared when the task ends.
     |> assign(:importing, %{})
     |> assign(:page_title, "Books")
     |> load_books()}
  end

  @impl true
  def handle_event("import", %{"importer" => importer_string} = params, socket) do
    force = params["force"] == "true"

    if importer_string in Ornitho.Importer.legit_importers_string() do
      importer = String.to_existing_atom(importer_string)
      task = Ornitho.Importer.run_import_async(importer, force: force)

      {:noreply,
       assign(socket, :importing, Map.put(socket.assigns.importing, task.ref, importer_string))}
    else
      {:noreply, put_flash(socket, :error, "Not an allowed importer.")}
    end
  end

  # The import task finished and returned a result. Stop monitoring it (flushing
  # the trailing :DOWN), then reflect success or a handled {:error, _} in the UI.
  @impl true
  def handle_info({ref, result}, socket) when is_map_key(socket.assigns.importing, ref) do
    Process.demonitor(ref, [:flush])
    name = importer_name(socket.assigns.importing[ref])

    socket =
      case result do
        {:ok, _} -> flash_importer(socket, :info, name, "import complete")
        {:error, _} -> flash_importer(socket, :error, name, "import failed")
      end

    {:noreply, finish_import(socket, ref)}
  end

  # The import task crashed (an uncaught exception or exit) before returning a
  # result; async_nolink delivers it here instead of taking down the LiveView.
  def handle_info({:DOWN, ref, :process, _pid, _reason}, socket)
      when is_map_key(socket.assigns.importing, ref) do
    name = importer_name(socket.assigns.importing[ref])

    {:noreply,
     socket
     |> flash_importer(:error, name, "import failed")
     |> finish_import(ref)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp finish_import(socket, ref) do
    socket
    |> assign(:importing, Map.delete(socket.assigns.importing, ref))
    |> load_books()
  end

  defp flash_importer(socket, kind, name, message) do
    put_flash(socket, kind, "#{name}: #{message}")
  end

  # The importer module's human-readable name; it is loaded by the time an import
  # was started, so the atom is guaranteed to exist.
  defp importer_name(importer_string) do
    String.to_existing_atom(importer_string).name()
  end

  defp importing?(importing, importer_string) do
    importer_string in Map.values(importing)
  end

  defp load_books(socket) do
    socket
    |> assign(:books, Ornitho.Finder.Book.all())
    |> assign(:importers, Ornitho.Importer.unimported())
  end

  attr :class, :string, default: nil

  defp importing_spinner(assigns) do
    ~H"""
    <span class={["mt-1 flex items-center gap-1 text-xs font-semibold leading-6", @class]}>
      <.icon name="hero-arrow-path" class="h-3 w-3 animate-spin" />
      <span>Importing<span class="sr-only">, please wait</span></span>
    </span>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header class="text-xl">
      {@page_title}
    </.header>
    <p :if={@books == []} id="taxonomy-index-books-empty" class="mb-10 text-zinc-500">
      No taxonomy books have been imported yet.<%= if @importers != [] do %>
        Choose one from the list below to import.
      <% end %>
    </p>
    <.simpler_table :if={@books != []} id="taxonomy-index-books" rows={@books} class="mb-10">
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
        <%= if importing?(@importing, book.importer) do %>
          <.importing_spinner class="text-red-600" />
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
          <%= if importing?(@importing, Atom.to_string(importer)) do %>
            <.importing_spinner class="text-zinc-700" />
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
