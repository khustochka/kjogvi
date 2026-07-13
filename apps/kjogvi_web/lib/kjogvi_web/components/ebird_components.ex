defmodule KjogviWeb.EbirdComponents do
  @moduledoc """
  Components for the eBird regions admin pages.
  """

  use Phoenix.Component

  @status_labels %{
    matched: "matched",
    matched_mixed: "matched (mixed)",
    matched_iso_extra: "matched (ISO extra)",
    partial: "partial",
    unmatched: "unmatched"
  }

  @status_classes %{
    matched: "bg-forest-100 text-forest-700",
    matched_mixed: "bg-teal-100 text-teal-700",
    matched_iso_extra: "bg-sky-100 text-sky-700",
    partial: "bg-amber-100 text-amber-700",
    unmatched: "bg-stone-100 text-stone-600"
  }

  def ebird_status_label(status), do: Map.fetch!(@status_labels, status)

  @doc """
  Renders a derived eBird country match status as a text chip.
  """
  attr :status, :atom, required: true
  attr :rest, :global

  def ebird_status_badge(assigns) do
    assigns = assign(assigns, :classes, Map.fetch!(@status_classes, assigns.status))

    ~H"""
    <span
      class={["inline-block px-2 py-0.5 text-xs font-medium rounded-full shrink-0", @classes]}
      {@rest}
    >
      {ebird_status_label(@status)}
    </span>
    """
  end
end
