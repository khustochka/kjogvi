defmodule KjogviWeb.Live.Admin.Imports.Locations.Ebird do
  @moduledoc """
  Import of eBird's region tree into `ebird_locations` — the bootstrap (and
  "newer eBird dump") tool; the curated snapshot restore is the usual seed
  path.

  Fills (or refreshes) the table from the source JSON in the `Kjogvi.Datasets`
  storage (`Kjogvi.Geo.Ebird.Import.source_key/0`), which is uploaded there
  out-of-band — this card only reads it. The import runs in a single
  transaction and finishes in under a second, so it is run directly via
  `start_async/3` — the button shows a loading state and the result is
  reported with a flash.

  The import upserts on `code` and never touches the curated match state. To
  protect that curated state from a stray click, the card is guarded (see
  `Kjogvi.Geo.Import.Guard`): hard-disabled once eBird rows exist, and gated
  behind a confirm when the table is empty but a snapshot exists in storage
  (after a reset the right move is *restore*). Blocked when no source file
  exists in the storage, or when the storage is unconfigured or unreachable.
  """

  use KjogviWeb, :live_component

  alias Kjogvi.Datasets
  alias Kjogvi.Geo
  alias Kjogvi.Geo.Dump
  alias Kjogvi.Geo.Ebird.Import
  alias Kjogvi.Geo.EbirdLocation
  alias Kjogvi.Geo.Import.Guard

  def update(_assigns, socket) do
    {:ok,
     socket
     |> assign_new(:running, fn -> false end)
     |> assign_state()}
  end

  # Reads the import's preconditions and the current type counts so the template
  # can show what's there and whether this is a fresh import or a re-import.
  defp assign_state(socket) do
    counts = Geo.Ebird.location_counts_by_type()
    imported = counts != %{}

    socket
    |> assign(:source_state, Datasets.snapshot_status(Import.source_key()))
    |> assign(:imported, imported)
    |> assign(:counts, counts)
    |> assign(
      :guard,
      Guard.state(imported, Datasets.snapshot_status(Dump.storage_key(:ebird_locations)))
    )
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
     |> put_flash(:error, "eBird regions import crashed: #{inspect(reason)}")}
  end

  defp flash_for_result(socket, {:ok, %{count: count, skipped: skipped}}) do
    skipped_note =
      case skipped do
        [] -> ""
        codes -> " Skipped #{length(codes)}: #{Enum.join(codes, ", ")}."
      end

    put_flash(socket, :info, "Imported #{count} eBird regions.#{skipped_note}")
  end

  defp flash_for_result(socket, {:error, reason}) do
    put_flash(socket, :error, "eBird regions import failed: #{inspect(reason)}")
  end

  defp import_button_label(true), do: "Importing…"
  defp import_button_label(false), do: "Import"

  # The `:confirm` guard's tripwire text; nil for `:free` (no confirm).
  defp confirm_text(:confirm),
    do:
      "An eBird-locations snapshot exists in storage. The usual way to seed an " <>
        "empty database is Restore, not this raw import. Import raw eBird data anyway?"

  defp confirm_text(:free), do: nil

  defp total(counts, type), do: get_in(counts, [type, :total]) || 0

  def render(assigns) do
    ~H"""
    <div>
      <.main_flash id="ebird-import-flash" flash={@flash} />

      <ul class="text-sm text-slate-700 mb-4 space-y-1">
        <li :for={type <- EbirdLocation.location_types()}>
          {Phoenix.Naming.humanize(type)}: {total(@counts, type)}
        </li>
      </ul>

      <%= case @source_state do %>
        <% {:ok, modified_at} -> %>
          <p class="text-sm text-slate-700 mb-4">
            Source file from {Calendar.strftime(modified_at, "%Y-%m-%d %H:%M:%S UTC")}.
          </p>
          <%= if @guard == :blocked do %>
            <p id="ebird-import-blocked" class="text-sm text-amber-700">
              eBird locations already exist. Re-running the raw import would
              overwrite curated names; it is disabled here. Pull a newer dump
              from the console if you really need to.
            </p>
          <% else %>
            <.form id="ebird-import-form" for={nil} phx-submit="start_import" phx-target={@myself}>
              <.button disabled={@running} data-confirm={confirm_text(@guard)}>
                {import_button_label(@running)}
              </.button>
            </.form>
          <% end %>
        <% :none -> %>
          <p class="text-sm text-amber-700" id="ebird-import-no-source">
            No source file. Upload the eBird regions JSON to the datasets storage
            under <code>{Import.source_key()}</code> to enable the import.
          </p>
        <% :not_configured -> %>
          <p class="text-sm text-amber-700" id="ebird-import-storage-not-configured">
            Snapshot storage is not configured.
          </p>
        <% {:error, _reason} -> %>
          <p class="text-sm text-amber-700" id="ebird-import-source-check-failed">
            Checking for the source file failed.
          </p>
      <% end %>
    </div>
    """
  end
end
