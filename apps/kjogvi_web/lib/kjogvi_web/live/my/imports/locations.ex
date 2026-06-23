defmodule KjogviWeb.Live.My.Imports.Locations do
  @moduledoc """
  Admin-only import of ISO 3166 countries and subdivisions into locations.

  Fills (or refreshes) the `locations` table from the configured JSONL URL
  (`Kjogvi.Geo.Import`). The import runs in a single transaction and finishes in
  seconds, so it is run directly via `start_async/3` with no progress reporting —
  the button shows a loading state and the result is reported with a flash.

  The import upserts on `iso_code`, so it is re-runnable: with ISO data already
  present the button re-imports (updates existing rows from a newer release)
  rather than being disabled. Blocked only when no URL is configured
  (`LOCATIONS_IMPORT_URL`).
  """

  use KjogviWeb, :live_component

  alias Kjogvi.Geo
  alias Kjogvi.Geo.Import

  def update(%{user: _user}, socket) do
    {:ok,
     socket
     |> assign_new(:running, fn -> false end)
     |> assign_state()}
  end

  # Reads the import's preconditions and the current type counts so the template
  # can show what's there and whether this is a fresh import or a re-import.
  defp assign_state(socket) do
    socket
    |> assign(:url, Import.default_url())
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

      <%= cond do %>
        <% is_nil(@url) -> %>
          <p class="text-sm text-amber-700" id="locations-import-unconfigured">
            No import URL configured. Set the <code>LOCATIONS_IMPORT_URL</code>
            environment variable to enable the import.
          </p>
        <% true -> %>
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
      <% end %>
    </div>
    """
  end
end
