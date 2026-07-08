defmodule KjogviWeb.Live.Admin.Imports.Locations.Iso do
  @moduledoc """
  Import of ISO 3166 countries and subdivisions into common locations — the
  bootstrap (and "newer ISO release") tool; the curated snapshot restore is the
  usual seed path.

  Fills (or refreshes) the `locations` table from the source JSONL in the
  `Kjogvi.Datasets` storage (`Kjogvi.Geo.Import.source_key/0`), which is
  uploaded there out-of-band — this card only reads it. The import runs in a
  single transaction and finishes in seconds, so it is run directly via
  `start_async/3` with no progress reporting — the button shows a loading state
  and the result is reported with a flash.

  The import upserts on `iso_code`, so it is re-runnable: with ISO data already
  present the button re-imports (updates existing rows from a newer release)
  rather than being disabled. Blocked when no source file exists in the
  storage, or when the storage is unconfigured or unreachable.
  """

  use KjogviWeb, :live_component

  alias Kjogvi.Datasets
  alias Kjogvi.Geo
  alias Kjogvi.Geo.Import

  def update(_assigns, socket) do
    {:ok,
     socket
     |> assign_new(:running, fn -> false end)
     |> assign_state()}
  end

  # Reads the import's preconditions and the current type counts so the template
  # can show what's there and whether this is a fresh import or a re-import.
  defp assign_state(socket) do
    socket
    |> assign(:source_state, Datasets.snapshot_status(Import.source_key()))
    |> assign(:imported, Import.country_exists?())
    |> assign(:counts, Geo.location_counts_by_type())
  end

  def handle_event("start_import", _params, socket) do
    {:noreply,
     socket
     |> clear_flash()
     |> assign(:running, true)
     |> start_async(:import, fn -> Import.import() end)}
  end

  def handle_async(:import, {:ok, result}, socket) do
    {:noreply,
     socket
     |> assign(:running, false)
     |> assign_state()
     |> flash_for_result(result)}
  end

  def handle_async(:import, {:exit, reason}, socket) do
    {:noreply,
     socket
     |> assign(:running, false)
     |> assign_state()
     |> put_flash(:error, "Locations import crashed: #{inspect(reason)}")}
  end

  defp flash_for_result(socket, {:ok, _ids_by_iso}) do
    counts = socket.assigns.counts
    countries = Map.get(counts, :country, 0)
    subdivisions = Map.get(counts, :subdivision1, 0)

    put_flash(
      socket,
      :info,
      "Imported #{countries} countries and #{subdivisions} subdivisions."
    )
  end

  defp flash_for_result(socket, {:error, reason}) do
    put_flash(socket, :error, "Locations import failed: #{inspect(reason)}")
  end

  defp import_button_label(true, _imported), do: "Importing…"
  defp import_button_label(false, true), do: "Re-import"
  defp import_button_label(false, false), do: "Import"

  def render(assigns) do
    ~H"""
    <div>
      <.main_flash id="locations-import-flash" flash={@flash} />

      <ul class="text-sm text-slate-700 mb-4 space-y-1">
        <li>Countries: {Map.get(@counts, :country, 0)}</li>
        <li>Subdivisions: {Map.get(@counts, :subdivision1, 0)}</li>
      </ul>

      <%= case @source_state do %>
        <% {:ok, modified_at} -> %>
          <p class="text-sm text-slate-700 mb-4">
            Source file from {Calendar.strftime(modified_at, "%Y-%m-%d %H:%M:%S UTC")}.
          </p>
          <.form
            id="locations-import-form"
            for={nil}
            phx-submit="start_import"
            phx-target={@myself}
          >
            <.button disabled={@running}>
              {import_button_label(@running, @imported)}
            </.button>
          </.form>
        <% :none -> %>
          <p class="text-sm text-amber-700" id="locations-import-no-source">
            No source file. Upload the ISO 3166 JSONL to the datasets storage
            under <code>{Import.source_key()}</code> to enable the import.
          </p>
        <% :not_configured -> %>
          <p class="text-sm text-amber-700" id="locations-import-storage-not-configured">
            Snapshot storage is not configured.
          </p>
        <% {:error, _reason} -> %>
          <p class="text-sm text-amber-700" id="locations-import-source-check-failed">
            Checking for the source file failed.
          </p>
      <% end %>
    </div>
    """
  end
end
