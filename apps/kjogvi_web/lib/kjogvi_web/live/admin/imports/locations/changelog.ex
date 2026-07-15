defmodule KjogviWeb.Live.Admin.Imports.Locations.Changelog do
  @moduledoc """
  Reapplies the curated common-location edits (`Kjogvi.Geo.Changelog`) that a
  raw ISO import leaves behind.

  Reads the changelog JSONL from the `Kjogvi.Datasets` storage
  (`Kjogvi.Geo.Changelog.source_key/0`), which is curated and uploaded there
  out-of-band — this card only reads it. Applying is a handful of single-row
  updates in one transaction, so it runs directly via `start_async/3` with no
  progress reporting — the button shows a loading state and the result is
  reported with a flash.

  Unlike the ISO and eBird import cards this one is unguarded: every op is an
  idempotent set keyed on `iso_code`, so re-applying cannot lose curated
  state — it restores it. Blocked only when no changelog exists in the
  storage, or when the storage is unconfigured or unreachable.
  """

  use KjogviWeb, :live_component

  alias Kjogvi.Datasets
  alias Kjogvi.Geo.Changelog

  def update(_assigns, socket) do
    {:ok,
     socket
     |> assign_new(:running, fn -> false end)
     |> assign_state()}
  end

  defp assign_state(socket) do
    assign(socket, :source_state, Datasets.snapshot_status(Changelog.source_key()))
  end

  def handle_event("apply_changelog", _params, socket) do
    {:noreply,
     socket
     |> clear_flash()
     |> assign(:running, true)
     |> start_async(:apply, fn -> Changelog.apply() end)}
  end

  def handle_async(:apply, {:ok, result}, socket) do
    {:noreply,
     socket
     |> assign(:running, false)
     |> assign_state()
     |> flash_for_result(result)}
  end

  def handle_async(:apply, {:exit, reason}, socket) do
    {:noreply,
     socket
     |> assign(:running, false)
     |> assign_state()
     |> put_flash(:error, "Changelog apply crashed: #{inspect(reason)}")}
  end

  defp flash_for_result(socket, {:ok, %{count: count, skipped: skipped}}) do
    skipped_note =
      case skipped do
        [] -> ""
        codes -> " Skipped #{length(codes)} (not found): #{Enum.join(codes, ", ")}."
      end

    put_flash(socket, :info, "Applied changes to #{count} locations.#{skipped_note}")
  end

  defp flash_for_result(socket, {:error, reason}) do
    put_flash(socket, :error, "Changelog apply failed: #{inspect(reason)}")
  end

  defp apply_button_label(true), do: "Applying…"
  defp apply_button_label(false), do: "Apply"

  def render(assigns) do
    ~H"""
    <div>
      <.main_flash id="changelog-apply-flash" flash={@flash} />

      <p class="text-sm text-slate-700 mb-4">
        Reapplies curated edits — short names, disabled duplicate territories,
        hidden flags — that the raw ISO import does not carry. Safe to re-run.
      </p>

      <%= case @source_state do %>
        <% {:ok, modified_at} -> %>
          <p class="text-sm text-slate-700 mb-4">
            Changelog from {Calendar.strftime(modified_at, "%Y-%m-%d %H:%M:%S UTC")}.
          </p>
          <.form
            id="changelog-apply-form"
            for={nil}
            phx-submit="apply_changelog"
            phx-target={@myself}
          >
            <.button disabled={@running}>{apply_button_label(@running)}</.button>
          </.form>
        <% :none -> %>
          <p class="text-sm text-amber-700" id="changelog-apply-no-source">
            No changelog file. Upload the changelog JSONL to the datasets storage
            under <code>{Changelog.source_key()}</code> to enable this.
          </p>
        <% :not_configured -> %>
          <p class="text-sm text-amber-700" id="changelog-apply-storage-not-configured">
            Snapshot storage is not configured.
          </p>
        <% {:error, _reason} -> %>
          <p class="text-sm text-amber-700" id="changelog-apply-source-check-failed">
            Checking for the changelog file failed.
          </p>
      <% end %>
    </div>
    """
  end
end
