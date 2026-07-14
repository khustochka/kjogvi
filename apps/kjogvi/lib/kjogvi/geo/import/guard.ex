defmodule Kjogvi.Geo.Import.Guard do
  @moduledoc """
  The raw-import guard shared by the ISO and eBird bootstrap cards: derives how
  a bootstrap import should behave from whether its dataset already has rows and
  whether a curated snapshot exists in storage.

  Three states protect curated work (curation workflow doc §4):

    * `:blocked` — the dataset already has rows. Re-running a bootstrap import
      would refresh name fields over hand-fixed data, so the card refuses from
      the UI. (Pulling a genuinely newer raw release stays a console affair.)
    * `:confirm` — the dataset is empty but a snapshot exists in storage. After
      a reset the right move is *restore*; the confirm is the tripwire that says
      so. A storage check that itself failed is treated the same way, since a
      snapshot may exist.
    * `:free` — the dataset is empty and no snapshot exists (or storage is
      unconfigured, so there can be none). The bootstrap case: import runs
      without ceremony.
  """

  @doc """
  `imported` is whether the dataset already has rows; `snapshot_state` is a
  `Kjogvi.Datasets.snapshot_status/1` result for the dataset's snapshot key.
  """
  def state(true, _snapshot_state), do: :blocked
  def state(false, {:ok, _modified_at}), do: :confirm
  def state(false, {:error, _reason}), do: :confirm
  def state(false, :none), do: :free
  def state(false, :not_configured), do: :free
end
