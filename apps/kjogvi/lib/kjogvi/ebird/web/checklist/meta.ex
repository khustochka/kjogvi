defmodule Kjogvi.Ebird.Web.Checklist.Meta do
  @moduledoc """
  Structure that represents eBird checklist metadata, as fetched from checklists page.
  """

  @type t() :: %__MODULE__{}

  defstruct [:ebird_id, :date, :time, :location, :county, :region, :country]
end
