defmodule KjogviWeb.EbirdComponents do
  @moduledoc """
  Components for the eBird regions admin pages.
  """

  use Phoenix.Component

  @status_labels %{
    matched: "matched",
    iso_extra: "ISO extra",
    ebird_only_subregions: "eBird-only subregions",
    name_candidate: "name-pass candidate",
    ebird_only: "eBird only",
    mixed: "mixed"
  }

  @status_classes %{
    matched: "bg-forest-100 text-forest-700",
    iso_extra: "bg-sky-100 text-sky-700",
    ebird_only_subregions: "bg-fuchsia-100 text-fuchsia-700",
    name_candidate: "bg-teal-100 text-teal-700",
    ebird_only: "bg-violet-100 text-violet-700",
    mixed: "bg-stone-100 text-stone-600"
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
