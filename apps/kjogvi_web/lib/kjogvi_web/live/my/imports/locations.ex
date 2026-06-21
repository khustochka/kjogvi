defmodule KjogviWeb.Live.My.Imports.Locations do
  @moduledoc """
  Admin-only import of ISO 3166 countries and subdivisions into locations.

  A one-shot fill of an empty `locations` table from the configured JSONL URL
  (`Kjogvi.Geo.Import`). The import runs in a single transaction and finishes in
  seconds, so it is run directly via `start_async/3` with no progress reporting —
  the button shows a loading state and the result is reported with a flash.

  Blocked when no URL is configured (`LOCATIONS_IMPORT_URL`) or when ISO data is already
  present; the underlying `Kjogvi.Geo.Import` enforces the latter regardless.
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
  # can show what's there and whether importing is possible.
  defp assign_state(socket) do
    socket
    |> assign(:url, Import.default_url())
    |> assign(:already_imported, Import.country_exists?())
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

  defp flash_for_result(socket, {:error, :already_imported}) do
    put_flash(socket, :error, "Locations are already imported.")
  end

  defp flash_for_result(socket, {:error, reason}) do
    put_flash(socket, :error, "Locations import failed: #{inspect(reason)}")
  end

  def render(assigns) do
    ~H"""
    <div>
      <.main_flash id="locations-import-flash" flash={@flash} />

      <p class="text-sm text-slate-600 mb-4">
        Fills the empty locations table with ISO 3166 countries and subdivisions.
        One-shot: it is disabled once any country exists.
      </p>

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
        <% @already_imported -> %>
          <p class="text-sm text-slate-500" id="locations-import-done">
            Already has {Map.get(@counts, :country, 0)} countries and
            {Map.get(@counts, :subdivision1, 0)} subdivisions — import disabled.
          </p>
        <% true -> %>
          <.form
            id="locations-import-form"
            for={nil}
            phx-submit="start_import"
            phx-target={@myself}
          >
            <.button disabled={@running}>
              {if @running, do: "Importing…", else: "Import"}
            </.button>
          </.form>
      <% end %>
    </div>
    """
  end
end
